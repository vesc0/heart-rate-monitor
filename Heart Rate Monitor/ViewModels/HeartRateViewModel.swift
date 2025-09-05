//
//  HeartRateViewModel.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/2/25.
//

import Foundation
import SwiftUI

class HeartRateViewModel: ObservableObject {
    // Phase / UI
    @Published var phase: SessionPhase = .idle
    @Published var currentBPM: Int? = nil
    @Published var heartScale: CGFloat = 1.0
    @Published var secondsLeft: Int = 0
    @Published var log: [HeartRateEntry] = []

    // Taps & computation
    private var tapTimes: [Date] = []
    /// Exposed read-only flag for the View
    var hasTapped: Bool {
        !tapTimes.isEmpty
    }
    
    private var validIntervals: [TimeInterval] = []
    private let smoothingWindow = 5

    // Durations
    private let measureDuration: TimeInterval = 12
    private let previewDuration: TimeInterval = 10
    private let minValidInterval: TimeInterval = 0.27
    private let maxValidInterval: TimeInterval = 1.50

    // Timers
    private var phaseTimer: Timer?
    private var countdownTimer: Timer?
    private var autoBeatTimer: Timer?

    // Persistence
    private let saveKey = "HeartRateLog"

    init() { loadData() }

    // MARK: - Session
    func startSession() {
        resetInMemoryOnly()
        phase = .measuring
        // Timer starts on first tap
    }

    func recordTap() {
        guard phase == .measuring || phase == .preview else { return }
        let now = Date()
        tapTimes.append(now)

        // If this is the first tap in measuring, start the 12s measurement countdown
        if phase == .measuring && tapTimes.count == 1 {
            startPhase(duration: measureDuration)
        }

        // Compute interval if not first tap
        if let last = tapTimes.dropLast().last {
            let interval = now.timeIntervalSince(last)
            guard interval >= minValidInterval, interval <= maxValidInterval else { return }

            validIntervals.append(interval)
            updateLiveBPM()

            // Always pulse heart on tap
            pulseHeart()
        }
    }

    private func finishMeasuring() {
        updateLiveBPM()
        phase = .preview
        startAutoBeat()
        startPhase(duration: previewDuration)
    }

    private func endSession() {
        let finalBPM = computeAverageBPM(from: validIntervals)
        currentBPM = finalBPM

        // Only save if we're in preview phase (means it wasn't stopped early)
        if let bpm = finalBPM, phase == .preview {
            let entry = HeartRateEntry(bpm: bpm, date: Date())
            log.insert(entry, at: 0)
            saveData()
        }

        phase = .finished
        invalidateAllTimers()
    }

    func startNewSession() {
        invalidateAllTimers()
        resetInMemoryOnly()
        phase = .idle
    }
    
    func stopSession() {
        invalidateAllTimers()
        resetInMemoryOnly()
        phase = .idle
    }

    // MARK: - Phase timers
    private func startPhase(duration: TimeInterval) {
        secondsLeft = Int(duration)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 { t.invalidate() }
        }

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.phase == .measuring {
                self.finishMeasuring()
            } else if self.phase == .preview {
                self.endSession()
            }
        }
    }

    // MARK: - Heart beat
    private func startAutoBeat() {
        autoBeatTimer?.invalidate()
        guard let bpm = currentBPM, bpm > 0 else { return }
        let interval = 60.0 / Double(bpm)
        autoBeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pulseHeart()
        }
    }

    private func pulseHeart() {
        withAnimation(.easeInOut(duration: 0.12)) {
            self.heartScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.12)) {
                self.heartScale = 1.0
            }
        }
    }

    // MARK: - BPM math
    private func updateLiveBPM() {
        let bpm = computeAverageBPM(from: Array(validIntervals.suffix(smoothingWindow)))
        currentBPM = bpm
        if phase == .preview { startAutoBeat() }
    }

    private func computeAverageBPM(from intervals: [TimeInterval]) -> Int? {
        guard !intervals.isEmpty else { return nil }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return nil }
        return Int(60.0 / avg)
    }

    // MARK: - Helpers
    private func resetInMemoryOnly() {
        currentBPM = nil
        heartScale = 1.0
        secondsLeft = 0
        tapTimes.removeAll()
        validIntervals.removeAll()
    }

    private func invalidateAllTimers() {
        phaseTimer?.invalidate(); phaseTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        autoBeatTimer?.invalidate(); autoBeatTimer = nil
    }

    // MARK: - Persistence
    func saveData() {
        if let encoded = try? JSONEncoder().encode(log) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([HeartRateEntry].self, from: data) {
            log = decoded
        }
    }
}
