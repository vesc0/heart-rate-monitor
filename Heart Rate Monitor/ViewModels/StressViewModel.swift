//
//  StressViewModel.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 3/1/26.
//

import Foundation
import AVFoundation
import SwiftUI

final class StressViewModel: NSObject, ObservableObject {

    // MARK: UI state

    @Published var phase: SessionPhase = .idle
    @Published var currentBPM: Int?     = nil
    @Published var secondsLeft: Int     = 0
    @Published var heartScale: CGFloat  = 1.0
    @Published var canShowBPM: Bool     = false
    @Published var errorMessage: String?

    // Result populated after the API responds.
    @Published var stressResult: StressPredictResponse?

    // Demographics from user profile (set by the view before starting).
    var userAge: Int?
    var userGender: String?
    var userHeightCm: Int?
    var userWeightKg: Int?

    // True while waiting for the server prediction.
    @Published var isPredicting: Bool = false

    // MARK: Internal state

    private var stoppedEarly = false

    // Calibration
    private var calibrationBeats: Int = 0
    private let calibrationBeatsRequired = 4

    // Measurement
    private var measurementStartTime: CFTimeInterval?
    private var revealTimeElapsed = false
    private var measurementIntervals: [TimeInterval] = []

    // Capture
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "stress.hr.capture")

    // Timers
    private var phaseTimer: Timer?
    private var countdownTimer: Timer?
    private var bpmRevealTimer: Timer?

    // Signal processing
    private var lastCentered: Double = 0
    private var ema: Double?
    private var window: [Double] = []
    private let windowSize = 45
    private var lastPeakTS: CFTimeInterval?

    // Constraints
    private let minInt: TimeInterval = 0.27   // ~220 BPM
    private let maxInt: TimeInterval = 1.50   // ~40 BPM

    // Durations – 60 s measurement window for HRV
    private let measureDuration: TimeInterval = 60
    private let bpmRevealAfter: TimeInterval  = 4.0

    private let api = APIService.shared

    // MARK: - Session lifecycle

    func startSession() {
        guard phase == .idle || phase == .finished else { return }
        reset()
        stoppedEarly = false
        phase = .measuring

        captureQueue.async {
            self.configureSessionIfNeeded()
            self.session.startRunning()

            DispatchQueue.main.async {
                guard self.session.isRunning else { return }
                self.turnTorch(on: true)
            }
        }
    }

    func stopSessionEarly() {
        stoppedEarly = true
        phase = .idle
        cleanupCamera()
        invalidateTimers()
    }

    private func endSession() {
        if !stoppedEarly {
            currentBPM = computeBPM(from: measurementIntervals)
            phase = .finished
            requestPrediction()
        } else {
            currentBPM = nil
            phase = .idle
        }
        cleanupCamera()
        invalidateTimers()
    }

    // MARK: - Stress prediction

    // Compute HRV features from measurementIntervals and call the API.
    private func requestPrediction() {
        guard let features = computeHRVFeatures() else {
            errorMessage = "Not enough beats to analyze. Try again."
            return
        }

        isPredicting = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.api.predictStress(features: features)
                self.stressResult = result
            } catch {
                self.errorMessage = "Prediction failed: \(error.localizedDescription)"
            }
            self.isPredicting = false
        }
    }

    // Build a StressPredictRequest from the collected RR intervals.
    private func computeHRVFeatures() -> StressPredictRequest? {
        // Convert to milliseconds
        let rr = measurementIntervals.map { $0 * 1000.0 }
        guard rr.count >= 10 else { return nil }

        let n = Double(rr.count)
        let meanRR   = rr.reduce(0, +) / n
        let medianRR = rr.sorted()[rr.count / 2]

        let variance = rr.reduce(0.0) { $0 + pow($1 - meanRR, 2) } / (n - 1)
        let sdnn     = sqrt(variance)
        let cvRR     = meanRR > 0 ? sdnn / meanRR : 0

        // Successive differences
        let diffs = zip(rr.dropFirst(), rr).map { $0 - $1 }
        let rmssd: Double = {
            guard !diffs.isEmpty else { return 0 }
            let sumSq = diffs.reduce(0.0) { $0 + $1 * $1 }
            return sqrt(sumSq / Double(diffs.count))
        }()
        let pnn50: Double = {
            guard !diffs.isEmpty else { return 0 }
            let count = diffs.filter { abs($0) > 50 }.count
            return Double(count) / Double(diffs.count) * 100
        }()
        let pnn20: Double = {
            guard !diffs.isEmpty else { return 0 }
            let count = diffs.filter { abs($0) > 20 }.count
            return Double(count) / Double(diffs.count) * 100
        }()

        // Heart rate stats (from each RR interval)
        let hrs = rr.map { 60000.0 / $0 }
        let meanHR  = hrs.reduce(0, +) / Double(hrs.count)
        let minHR   = hrs.min() ?? 0
        let maxHR   = hrs.max() ?? 0
        let hrRange = maxHR - minHR
        let stdHR: Double = {
            guard hrs.count > 1 else { return 0 }
            let m = meanHR
            let v = hrs.reduce(0.0) { $0 + pow($1 - m, 2) } / Double(hrs.count - 1)
            return sqrt(v)
        }()

        // Frequency-domain HRV (Lomb-Scargle approximation via simple PSD)
        var lfPower = 0.0, hfPower = 0.0, lfHfRatio = 0.0
        var totalPower = 0.0, lfNorm = 0.0

        if rr.count >= 20 {
            let rrSec = rr.map { $0 / 1000.0 }
            var tRR = [Double]()
            var cumulative = 0.0
            for r in rrSec {
                cumulative += r
                tRR.append(cumulative)
            }
            // Subtract first to start at 0
            let t0 = tRR[0]
            tRR = tRR.map { $0 - t0 }

            // Interpolate to uniform 4 Hz
            let fs = 4.0
            let tMax = tRR.last ?? 0
            let nSamples = Int(tMax * fs)
            if nSamples > 10 {
                var uniform = [Double]()
                for i in 0..<nSamples {
                    let t = Double(i) / fs
                    // Linear interpolation
                    var idx = 0
                    while idx < tRR.count - 1 && tRR[idx + 1] < t { idx += 1 }
                    if idx >= tRR.count - 1 {
                        uniform.append(rr.last ?? meanRR)
                    } else {
                        let frac = (t - tRR[idx]) / max(tRR[idx + 1] - tRR[idx], 1e-9)
                        uniform.append(rr[idx] + frac * (rr[min(idx + 1, rr.count - 1)] - rr[idx]))
                    }
                }
                // Detrend
                let uMean = uniform.reduce(0, +) / Double(uniform.count)
                let detrended = uniform.map { $0 - uMean }

                // Simple DFT power spectrum (enough for LF/HF bands)
                let N = detrended.count
                let freqRes = fs / Double(N)
                var psd = [Double](repeating: 0, count: N / 2 + 1)
                for k in 0...N/2 {
                    var realPart = 0.0, imagPart = 0.0
                    for ni in 0..<N {
                        let angle = -2.0 * .pi * Double(k) * Double(ni) / Double(N)
                        realPart += detrended[ni] * cos(angle)
                        imagPart += detrended[ni] * sin(angle)
                    }
                    psd[k] = (realPart * realPart + imagPart * imagPart) / (fs * Double(N))
                }

                // Integrate LF (0.04–0.15 Hz) and HF (0.15–0.40 Hz)
                for k in 0..<psd.count {
                    let freq = Double(k) * freqRes
                    if freq >= 0.04 && freq < 0.15 { lfPower += psd[k] * freqRes }
                    if freq >= 0.15 && freq < 0.40 { hfPower += psd[k] * freqRes }
                }
                totalPower = lfPower + hfPower
                lfHfRatio = hfPower > 0 ? lfPower / hfPower : 0
                lfNorm = totalPower > 0 ? lfPower / totalPower * 100 : 0
            }
        }

        // Nonlinear: Poincaré SD1, SD2
        // SD1 = SDSD/√2 ≈ RMSSD/√2 (SDSD ≈ RMSSD for large N)
        let sd1: Double = diffs.count > 1 ? rmssd / sqrt(2.0) : 0
        let sd2Sq = 2.0 * sdnn * sdnn - sd1 * sd1
        let sd2: Double = sd2Sq > 0 ? sqrt(sd2Sq) : 0
        let sdRatio: Double = sd1 > 0 ? sd2 / sd1 : 0

        // Demographics (optional)
        let age: Double? = userAge.map { Double($0) }
        let genderMale: Double? = userGender.map { $0 == "male" ? 1.0 : 0.0 }
        let heightCm: Double? = userHeightCm.map { Double($0) }
        let weightKg: Double? = userWeightKg.map { Double($0) }

        return StressPredictRequest(
            sdnn:       sdnn,
            medianRR:   medianRR,
            cvRR:       cvRR,
            rmssd:      rmssd,
            pnn50:      pnn50,
            pnn20:      pnn20,
            meanHR:     meanHR,
            stdHR:      stdHR,
            minHR:      minHR,
            maxHR:      maxHR,
            hrRange:    hrRange,
            lfPower:    lfPower,
            hfPower:    hfPower,
            lfHfRatio:  lfHfRatio,
            totalPower: totalPower,
            lfNorm:     lfNorm,
            sd1:        sd1,
            sd2:        sd2,
            sdRatio:    sdRatio,
            age:        age,
            genderMale: genderMale,
            heightCm:   heightCm,
            weightKg:   weightKg
        )
    }

    // MARK: - Timers

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
            self?.endSession()
        }
    }

    private func scheduleBPMReveal(after delay: TimeInterval) {
        canShowBPM = false
        revealTimeElapsed = false
        bpmRevealTimer?.invalidate()
        bpmRevealTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.revealTimeElapsed = true
            self.updateCanShowBPM()
        }
    }

    private func updateCanShowBPM() {
        canShowBPM = (measurementStartTime != nil) && revealTimeElapsed
    }

    private func invalidateTimers() {
        phaseTimer?.invalidate();    phaseTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        bpmRevealTimer?.invalidate(); bpmRevealTimer = nil
    }

    // MARK: - Camera setup (identical to AutoHeartRateViewModel)

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
        session.sessionPreset = .low

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else {
            errorMessage = "No back camera available."
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        device = cam

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
                try dev.setTorchModeOn(level: min(0.7, AVCaptureDevice.maxAvailableTorchLevel))
            } else {
                dev.torchMode = .off
            }
            dev.unlockForConfiguration()
        } catch { /* ignore torch errors */ }
    }

    private func cleanupCamera() {
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

    // MARK: - Signal processing

    private func reset() {
        currentBPM = nil
        secondsLeft = 0
        heartScale = 1.0
        errorMessage = nil
        stressResult = nil
        isPredicting = false

        ema = nil
        window.removeAll()
        lastCentered = 0
        lastPeakTS = nil

        calibrationBeats = 0
        measurementStartTime = nil
        revealTimeElapsed = false
        measurementIntervals.removeAll()

        canShowBPM = false
    }

    private func handleSample(_ redMean: Double) {
        guard phase == .measuring else { return }

        if ema == nil { ema = redMean }
        ema = 0.2 * redMean + 0.8 * (ema ?? redMean)
        let value = ema ?? redMean

        window.append(value)
        if window.count > windowSize { window.removeFirst() }
        let mean = window.reduce(0, +) / Double(window.count)
        let centered = value - mean

        let variance = window.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(max(1, window.count - 1))
        let std = sqrt(variance)
        let threshold = max(0.5 * std, 0.5)

        let derivative = centered - lastCentered
        let isLocalMax = (derivative <= 0) && (lastCentered > threshold)

        if isLocalMax {
            let now = CACurrentMediaTime()
            if let last = lastPeakTS {
                let dt = now - last
                if dt >= minInt && dt <= maxInt {
                    if let start = measurementStartTime, now >= start {
                        measurementIntervals.append(dt)
                        currentBPM = computeBPM(from: Array(measurementIntervals.suffix(5)))
                    } else {
                        calibrationBeats += 1
                        if calibrationBeats >= calibrationBeatsRequired && measurementStartTime == nil {
                            measurementStartTime = now
                            measurementIntervals.removeAll()
                            currentBPM = nil
                            canShowBPM = false
                            revealTimeElapsed = false
                            startPhase(duration: measureDuration)
                            scheduleBPMReveal(after: bpmRevealAfter)
                        }
                    }
                    pulseHeart()
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
        withAnimation(.easeInOut(duration: 0.12)) { heartScale = 1.2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.12)) { self.heartScale = 1.0 }
        }
    }
}

// MARK: - Video delegate

extension StressViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        CVPixelBufferLockBaseAddress(px, .readOnly)
        let width  = CVPixelBufferGetWidth(px)
        let height = CVPixelBufferGetHeight(px)
        let bpr    = CVPixelBufferGetBytesPerRow(px)
        guard let base = CVPixelBufferGetBaseAddress(px)?.assumingMemoryBound(to: UInt8.self) else {
            CVPixelBufferUnlockBaseAddress(px, .readOnly)
            return
        }

        var sum: Double = 0
        var count: Int  = 0
        for y in stride(from: 0, to: height, by: 8) {
            let row = base + y * bpr
            for x in stride(from: 0, to: width * 4, by: 32) {
                sum += Double(row[x + 2])
                count += 1
            }
        }

        CVPixelBufferUnlockBaseAddress(px, .readOnly)
        guard count > 0 else { return }
        let redMean = sum / Double(count)

        DispatchQueue.main.async { [weak self] in
            self?.handleSample(redMean)
        }
    }
}
