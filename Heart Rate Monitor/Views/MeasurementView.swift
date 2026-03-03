//
//  MeasurementView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 3/3/26.
//

import SwiftUI

enum MeasurementMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case automatic = "Automatic"
    var id: String { rawValue }
}

struct MeasurementView: View {
    @ObservedObject var vm: HeartRateViewModel
    @State private var mode: MeasurementMode = .automatic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker pinned at top
                Picker("Mode", selection: $mode) {
                    ForEach(MeasurementMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Measurement content
                Group {
                    switch mode {
                    case .manual:
                        ManualContentView(vm: vm)
                    case .automatic:
                        AutoContentView(vm: vm)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Measure")
        }
    }
}

// MARK: - Manual Measurement Content (extracted from ManualView)

private struct ManualContentView: View {
    @ObservedObject var vm: HeartRateViewModel

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

                    Text("Manual Measurement")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Find your pulse on your neck or wrist, then tap the heart in rhythm for 12 seconds.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Button {
                        vm.startSession()
                    } label: {
                        Label("Start Manual Session", systemImage: "play.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundColor(.white)
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
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundColor(.white)
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

// MARK: - Automatic Measurement Content (extracted from AutoView)

private struct AutoContentView: View {
    @ObservedObject var vm: HeartRateViewModel
    @StateObject private var autoVM = AutoHeartRateViewModel()

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

                        Text("Automatic Measurement")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Place your fingertip over the camera and keep it still. The 12-second timer starts after detecting your first beats.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Button {
                            autoVM.startSession()
                        } label: {
                            Label("Start Automatic Session", systemImage: "play.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundColor(.white)
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
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 64)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }

                if let err = autoVM.errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
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
                .padding(.bottom, 20)
            }
        }
        // When session ends, save to shared history
        .onChange(of: autoVM.phase) { _, newPhase in
            if newPhase == .finished, let bpm = autoVM.currentBPM {
                let entry = HeartRateEntry(bpm: bpm, date: Date())
                vm.addEntry(entry)
            }
        }
    }
}
