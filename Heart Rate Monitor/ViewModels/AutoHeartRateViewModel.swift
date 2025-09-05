//
//  AutoHeartRateViewModel.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/3/25.
//

import Foundation
import AVFoundation
import SwiftUI

final class AutoHeartRateViewModel: NSObject, ObservableObject {
    // UI
    @Published var phase: SessionPhase = .idle
    @Published var currentBPM: Int? = nil
    @Published var secondsLeft: Int = 0
    @Published var heartScale: CGFloat = 1.0
    @Published var errorMessage: String?
    
    // State
    private var stoppedEarly = false

    // Capture
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "auto.hr.capture")

    // Timers
    private var phaseTimer: Timer?
    private var countdownTimer: Timer?

    // BPM detection (simple, robust starter)
    private var lastCentered: Double = 0
    private var ema: Double?
    private var window: [Double] = []     // rolling baseline
    private let windowSize = 45           // ~0.75s at 60fps
    private var lastPeakTS: CFTimeInterval?
    private var intervals: [TimeInterval] = []

    // Constraints (same as manual)
    private let minInt: TimeInterval = 0.27  // ~220 bpm
    private let maxInt: TimeInterval = 1.50  // ~40 bpm

    // Durations
    private let measureDuration: TimeInterval = 12
    private let previewDuration: TimeInterval = 10

    // MARK: Session lifecycle
    func startSession() {
        guard phase == .idle || phase == .finished else { return }
        reset()
        stoppedEarly = false
        phase = .measuring
        
        // Use the dedicated capture queue for all camera operations
        captureQueue.async {
            self.configureSessionIfNeeded()
            self.session.startRunning()
            
            // Only turn on torch if session is actually running
            DispatchQueue.main.async {
                guard self.session.isRunning else { return }
                self.turnTorch(on: true)
                self.startPhase(duration: self.measureDuration)
            }
        }
    }

    func stopSessionEarly() {
        stoppedEarly = true
        phase = .idle
        cleanupCamera()
        invalidateTimers()
    }

    private func finishMeasuring() {
        phase = .preview
        startPhase(duration: previewDuration)
        // Keep detecting beats and updating BPM live.
    }

    private func endSession() {
        if !stoppedEarly {
            // Final BPM = average over ALL intervals detected so far
            currentBPM = computeBPM(from: intervals)
            phase = .finished
        } else {
            currentBPM = nil
            phase = .idle
        }

        // Clean up capture
        cleanupCamera()
        invalidateTimers()
    }
    
    private func cleanupCamera() {
        // Make sure to cleanup on the same queue as started with
        if Thread.isMainThread {
            captureQueue.sync {
                turnTorch(on: false)
                session.stopRunning()
            }
        } else {
            turnTorch(on: false)
            session.stopRunning()
        }
    }

    deinit {
        cleanupCamera()
        invalidateTimers()
    }

    // MARK: Timers
    private func startPhase(duration: TimeInterval) {
        secondsLeft = Int(duration)

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 { t.invalidate() }
        }

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.phase == .measuring {
                self.finishMeasuring()
            } else if self.phase == .preview {
                self.endSession()
            }
        }
    }

    private func invalidateTimers() {
        phaseTimer?.invalidate(); phaseTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
    }

    // MARK: Capture setup
    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                DispatchQueue.main.async {
                    if ok { self?.configureSessionIfNeeded() }
                    else { self?.errorMessage = "Camera access denied." }
                }
            }
            return
        default:
            errorMessage = "Camera access denied. Enable it in Settings."
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .low  // only luminosity is needed, keep it light

        // Back camera
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else {
            errorMessage = "No back camera available."
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        device = cam

        // Force BGRA to read red channel easily
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                                     kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(videoOutput) else {
            errorMessage = "Cannot add video output."
            session.commitConfiguration()
            return
        }
        session.addOutput(videoOutput)

        // Prefer 30–60 fps if available
        try? cam.lockForConfiguration()
        if let range = cam.activeFormat.videoSupportedFrameRateRanges.first {
            let target = min(max(30.0, range.minFrameRate), range.maxFrameRate)
            cam.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(target))
            cam.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(target))
        }
        cam.unlockForConfiguration()

        session.commitConfiguration()
    }

    private func turnTorch(on: Bool) {
        guard let dev = device, dev.hasTorch else { return }
        do {
            try dev.lockForConfiguration()
            if on {
                // use a moderate level to reduce heat
                try dev.setTorchModeOn(level: min(0.7, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                dev.torchMode = .off
            }
            dev.unlockForConfiguration()
        } catch {
            // Ignore torch errors for now
        }
    }

    // MARK: Signal processing
    private func reset() {
        currentBPM = nil
        secondsLeft = 0
        heartScale = 1.0
        errorMessage = nil
        ema = nil
        window.removeAll()
        lastCentered = 0
        lastPeakTS = nil
        intervals.removeAll()
    }

    private func handleSample(_ redMean: Double) {
        // 1) Smooth via EMA
        if ema == nil { ema = redMean }
        ema = 0.2 * redMean + 0.8 * (ema ?? redMean)
        let value = ema ?? redMean

        // 2) Rolling baseline
        window.append(value)
        if window.count > windowSize { window.removeFirst() }
        let mean = window.reduce(0, +) / Double(window.count)
        let centered = value - mean

        // 3) Dynamic threshold from window stddev
        let variance = window.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(max(1, window.count - 1))
        let std = sqrt(variance)
        let threshold = max(0.5 * std, 0.5) // clamp to avoid overly small thresholds

        // 4) Peak detection: positive-to-negative slope near a local max AND above threshold
        let derivative = centered - lastCentered
        let isLocalMax = (derivative <= 0) && (lastCentered > threshold)

        if isLocalMax {
            let now = CACurrentMediaTime()
            if let last = lastPeakTS {
                let dt = now - last
                if dt >= minInt && dt <= maxInt {
                    intervals.append(dt)
                    DispatchQueue.main.async {
                        self.currentBPM = self.computeBPM(from: Array(self.intervals.suffix(5)))
                        self.pulseHeart() // beat on every detected peak
                    }
                }
            }
            lastPeakTS = now
        }

        lastCentered = centered
    }

    private func computeBPM(from intervals: [TimeInterval]) -> Int? {
        guard !intervals.isEmpty else { return nil }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return nil }
        return Int(60.0 / avg)
    }

    private func pulseHeart() {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.12)) { self.heartScale = 1.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.12)) { self.heartScale = 1.0 }
            }
        }
    }
}

// MARK: - Video frames → brightness
extension AutoHeartRateViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard phase == .measuring || phase == .preview else { return }
        guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(px, .readOnly)
        let width = CVPixelBufferGetWidth(px)
        let height = CVPixelBufferGetHeight(px)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(px)
        guard let base = CVPixelBufferGetBaseAddress(px)?.assumingMemoryBound(to: UInt8.self) else {
            CVPixelBufferUnlockBaseAddress(px, .readOnly)
            return
        }

        var sum: Double = 0
        var count: Int = 0

        // BGRA format: take 'R' at offset +2. Sample every 8th pixel in a 8x8 grid for speed.
        for y in stride(from: 0, to: height, by: 8) {
            let row = base + y * bytesPerRow
            for x in stride(from: 0, to: width * 4, by: 32) { // 8 pixels * 4 bytes per pixel
                sum += Double(row[x + 2])
                count += 1
            }
        }

        CVPixelBufferUnlockBaseAddress(px, .readOnly)
        guard count > 0 else { return }
        let redMean = sum / Double(count)      // 0…255

        // Process sample
        handleSample(redMean)
    }
}
