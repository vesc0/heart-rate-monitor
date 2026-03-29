//
//  MeasurementView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 3/3/26.
//

import SwiftUI
import UIKit

enum MeasurementCategory: String, CaseIterable, Identifiable {
    case heartRate = "Heart Rate"
    case stress = "Stress"
    var id: String { rawValue }
}

enum HeartRateMode: String, CaseIterable, Identifiable {
    case tap = "Tap"
    case camera = "Camera"
    var id: String { rawValue }
}

struct MeasurementView: View {
    @ObservedObject var vm: HeartRateViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var category: MeasurementCategory = .heartRate
    @State private var heartRateMode: HeartRateMode = .camera
    @StateObject private var autoVM = AutoHeartRateViewModel()
    @StateObject private var stressVM = StressViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $category) {
                    ForEach(MeasurementCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Measurement content
                Group {
                    switch category {
                    case .heartRate:
                        VStack(spacing: 0) {
                            TabView(selection: $heartRateMode) {
                                TapContentView(vm: vm) {
                                    stopCameraMeasurementIfNeeded()
                                }
                                    .tag(HeartRateMode.tap)

                                CameraContentView(vm: vm, autoVM: autoVM) {
                                    stopTapMeasurementIfNeeded()
                                }
                                    .tag(HeartRateMode.camera)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .indexViewStyle(.page(backgroundDisplayMode: .always))
                            .onAppear {
                                applyPageIndicatorColors()
                            }
                            .onChange(of: colorScheme) { _, _ in
                                applyPageIndicatorColors()
                            }
                            .onChange(of: heartRateMode) { _, newMode in
                                switch newMode {
                                case .tap:
                                    stopCameraMeasurementIfNeeded()
                                case .camera:
                                    stopTapMeasurementIfNeeded()
                                }
                            }
                        }
                    case .stress:
                        StressContentView(vm: vm, stressVM: stressVM) {
                            stopHeartRateMeasurementsIfNeeded()
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Measure")
            .onChange(of: category) { _, newCategory in
                switch newCategory {
                case .heartRate:
                    stopStressMeasurementIfNeeded()
                case .stress:
                    stopHeartRateMeasurementsIfNeeded()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    stopAllMeasurementsIfNeeded()
                }
            }
            .onDisappear {
                stopAllMeasurementsIfNeeded()
            }
        }
    }

    private func applyPageIndicatorColors() {
        if colorScheme == .light {
            UIPageControl.appearance().currentPageIndicatorTintColor = .systemRed
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray3.withAlphaComponent(0.65)
        } else {
            UIPageControl.appearance().currentPageIndicatorTintColor = .systemRed
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.35)
        }
    }

    private func stopTapMeasurementIfNeeded() {
        if vm.phase == .measuring {
            vm.stopSession()
        }
    }

    private func stopCameraMeasurementIfNeeded() {
        if autoVM.phase == .measuring {
            autoVM.stopSessionEarly()
        }
    }

    private func stopStressMeasurementIfNeeded() {
        if stressVM.phase == .measuring {
            stressVM.stopSessionEarly()
        }
    }

    private func stopHeartRateMeasurementsIfNeeded() {
        stopTapMeasurementIfNeeded()
        stopCameraMeasurementIfNeeded()
    }

    private func stopAllMeasurementsIfNeeded() {
        stopHeartRateMeasurementsIfNeeded()
        stopStressMeasurementIfNeeded()
    }
}

// MARK: - Stress Measurement Content

private struct StressContentView: View {
    @ObservedObject var vm: HeartRateViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject var stressVM: StressViewModel
    let onStart: () -> Void

    private var totalForCurrentPhase: Int {
        switch stressVM.phase {
        case .measuring: return 60
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            if stressVM.phase == .measuring {
                VStack(spacing: 0) {
                    CameraPreview(session: stressVM.session)
                        .frame(height: 160)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.black.opacity(0.5), .clear]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipped()
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 16) {
                if stressVM.phase == .idle {
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.bottom, 4)

                        Text("Stress Measurement")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Place your fingertip over the camera and keep it still for 60 seconds. The app will analyse your heart-rate variability and predict whether you are stressed.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Button {
                            onStart()
                            stressVM.userAge = auth.age.flatMap { Int($0) }
                            stressVM.userGender = auth.gender
                            stressVM.userHeightCm = auth.heightCm.flatMap { Int($0) }
                            stressVM.userWeightKg = auth.weightKg.flatMap { Int($0) }
                            stressVM.startSession()
                        } label: {
                            Label("Start Stress Session", systemImage: "play.fill")
                                .measurementPrimaryButtonStyle()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 64)
                        .padding(.top, 8)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)

                } else if stressVM.phase == .measuring {
                    VStack(spacing: 16) {
                        Spacer()

                        HeartTimerView(
                            heartScale: stressVM.heartScale,
                            secondsLeft: stressVM.secondsLeft,
                            totalSeconds: totalForCurrentPhase,
                            heartSize: 96,
                            color: .purple
                        )

                        if stressVM.canShowBPM, let bpm = stressVM.currentBPM {
                            Text("\(bpm) BPM")
                                .font(.system(size: 42, weight: .bold))
                        } else {
                            Text("Calibrating… keep fingertip on camera")
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                } else if stressVM.phase == .finished {
                    VStack(spacing: 20) {
                        if let bpm = stressVM.currentBPM {
                            Text("Heart Rate: \(bpm) BPM")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        if stressVM.isPredicting {
                            ProgressView("Analysing…")
                        } else if let result = stressVM.stressResult {
                            let pct = result.stressLevelPct
                            let color: Color = pct >= 70 ? .red : pct >= 40 ? .orange : .green
                            let icon = pct >= 50 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"

                            Image(systemName: icon)
                                .font(.system(size: 56))
                                .foregroundColor(color)

                            Text(String(format: "%.0f%%", pct))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(color)

                            Text(pct >= 70 ? "High Stress" : pct >= 40 ? "Moderate Stress" : "Low Stress")
                                .font(.title3)
                                .foregroundColor(color)
                        }

                        Button {
                            stressVM.phase = .idle
                        } label: {
                            Label("Done", systemImage: "checkmark")
                                .measurementPrimaryButtonStyle()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 64)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }

                Spacer()

                Group {
                    if stressVM.phase == .measuring {
                        Button(role: .destructive) {
                            stressVM.stopSessionEarly()
                        } label: {
                            Text("Stop")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .onChange(of: stressVM.phase) { _, newPhase in
            if newPhase == .finished, let bpm = stressVM.currentBPM {
                let stress = stressVM.stressResult.map { String(format: "%.0f%%", $0.stressLevelPct) }
                let entry = HeartRateEntry(bpm: bpm, date: Date(), stressLevel: stress)
                vm.addEntry(entry)
            }
        }
        .onChange(of: stressVM.stressResult?.stressLevelPct) { oldVal, newVal in
            if let pct = newVal,
               oldVal == nil,
               stressVM.phase == .finished,
               let bpm = stressVM.currentBPM {
                let level = String(format: "%.0f%%", pct)
                if let idx = vm.log.firstIndex(where: {
                    $0.bpm == bpm && $0.stressLevel == nil
                }) {
                    let old = vm.log[idx]
                    let updated = HeartRateEntry(
                        bpm: old.bpm,
                        date: old.date,
                        id: old.id,
                        stressLevel: level
                    )
                    vm.updateEntry(updated)
                }
            }
        }
        .alert("Flash Unavailable", isPresented: .constant(stressVM.flashUnavailableAlert != nil)) {
            Button("OK") {
                stressVM.flashUnavailableAlert = nil
                stressVM.stopSessionEarly()
            }
        } message: {
            if let alert = stressVM.flashUnavailableAlert {
                Text(alert)
            }
        }
    }
}

// MARK: - Tap Measurement Content

private struct TapContentView: View {
    @ObservedObject var vm: HeartRateViewModel
    let onStart: () -> Void

    private var totalForCurrentPhase: Int {
        switch vm.phase {
        case .measuring: return 12
        default: return 0
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            switch vm.phase {
            case .idle:
                VStack(spacing: 16) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.bottom, 4)

                    Text("Tap Measurement")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Find your pulse on your neck or wrist, then tap the heart in rhythm for 12 seconds.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button {
                        onStart()
                        vm.startSession()
                    } label: {
                        Label("Start Tap Session", systemImage: "play.fill")
                            .measurementPrimaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 64)
                    .padding(.top, 8)
                }
                .frame(maxHeight: .infinity, alignment: .center)

            case .measuring:
                VStack(spacing: 16) {
                    Spacer()

                    HeartTimerView(
                        heartScale: vm.heartScale,
                        secondsLeft: vm.secondsLeft,
                        totalSeconds: totalForCurrentPhase,
                        heartSize: 96,
                        color: .red
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vm.recordTap()
                    }

                    if let bpm = vm.currentBPM, vm.canShowBPM {
                        Text("\(bpm) BPM")
                            .font(.system(size: 42, weight: .bold))
                    } else if !vm.hasTapped {
                        Text("Tap the heart to begin…")
                            .foregroundColor(.gray)
                    } else {
                        Text("Keep tapping…")
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button("Stop") { vm.stopSession() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .padding(.bottom, 20)
                }

            case .finished:
                VStack(spacing: 16) {
                    if let bpm = vm.currentBPM {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("\(bpm) BPM")
                            .font(.system(size: 42, weight: .bold))

                        Text("Measurement complete")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No data recorded")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        vm.startNewSession()
                    } label: {
                        Label("New Measurement", systemImage: "arrow.counterclockwise")
                            .measurementPrimaryButtonStyle()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 64)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Camera Measurement Content

private struct CameraContentView: View {
    @ObservedObject var vm: HeartRateViewModel
    @ObservedObject var autoVM: AutoHeartRateViewModel
    let onStart: () -> Void

    private var totalForCurrentPhase: Int {
        switch autoVM.phase {
        case .measuring: return 12
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            // Camera preview only during measuring
            if autoVM.phase == .measuring {
                VStack(spacing: 0) {
                    CameraPreview(session: autoVM.session)
                        .frame(height: 160)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [.black.opacity(0.5), .clear]),
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipped()
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 16) {
                if autoVM.phase == .idle {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.bottom, 4)

                        Text("Camera Measurement")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Place your fingertip over the camera and keep it still. The 12-second timer starts after detecting your first beats.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Button {
                            onStart()
                            autoVM.startSession()
                        } label: {
                            Label("Start Camera Session", systemImage: "play.fill")
                                .measurementPrimaryButtonStyle()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 64)
                        .padding(.top, 8)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)

                } else if autoVM.phase == .measuring {
                    VStack(spacing: 16) {
                        Spacer()

                        HeartTimerView(
                            heartScale: autoVM.heartScale,
                            secondsLeft: autoVM.secondsLeft,
                            totalSeconds: totalForCurrentPhase,
                            heartSize: 96,
                            color: .red
                        )

                        if autoVM.canShowBPM, let bpm = autoVM.currentBPM {
                            Text("\(bpm) BPM")
                                .font(.system(size: 42, weight: .bold))
                        } else {
                            Text("Calibrating… keep fingertip on camera")
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                } else if autoVM.phase == .finished {
                    VStack(spacing: 16) {
                        if let bpm = autoVM.currentBPM {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)

                            Text("\(bpm) BPM")
                                .font(.system(size: 42, weight: .bold))

                            Text("Measurement complete")
                                .foregroundColor(.secondary)
                        } else {
                            Text("No result")
                                .foregroundColor(.secondary)
                        }

                        Button {
                            autoVM.phase = .idle
                        } label: {
                            Label("New Measurement", systemImage: "arrow.counterclockwise")
                                .measurementPrimaryButtonStyle()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 64)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }

                Spacer()

                // Bottom-fixed stop button during measurement
                Group {
                    if autoVM.phase == .measuring {
                        Button(role: .destructive) {
                            autoVM.stopSessionEarly()
                        } label: {
                            Text("Stop")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(.bottom, 44)
            }
        }
        // When session ends, save to shared history
        .onChange(of: autoVM.phase) { _, newPhase in
            if newPhase == .finished, let bpm = autoVM.currentBPM {
                let entry = HeartRateEntry(bpm: bpm, date: Date())
                vm.addEntry(entry)
            }
        }
        .alert("Flash Unavailable", isPresented: .constant(autoVM.flashUnavailableAlert != nil)) {
            Button("OK") {
                autoVM.flashUnavailableAlert = nil
                autoVM.stopSessionEarly()
            }
        } message: {
            if let alert = autoVM.flashUnavailableAlert {
                Text(alert)
            }
        }
    }
}

private extension View {
    func measurementPrimaryButtonStyle() -> some View {
        self
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundColor(.white)
    }
}
