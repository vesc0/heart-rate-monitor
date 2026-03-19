//
//  StressView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 3/1/26.
//

import SwiftUI

struct StressView: View {
    @ObservedObject var vm: HeartRateViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var stressVM = StressViewModel()

    private var totalForCurrentPhase: Int {
        switch stressVM.phase {
        case .measuring: return 60
        default: return 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview during measurement
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
                    // MARK: Idle
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
                                // Inject demographics from user profile
                                stressVM.userAge = auth.age.flatMap { Int($0) }
                                stressVM.userGender = auth.gender
                                stressVM.userHeightCm = auth.heightCm.flatMap { Int($0) }
                                stressVM.userWeightKg = auth.weightKg.flatMap { Int($0) }
                                stressVM.startSession()
                            } label: {
                                Label("Start Stress Session", systemImage: "play.fill")
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

                    // MARK: Measuring
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

                    // MARK: Finished
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
                                Text("Done")
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

                    if let err = stressVM.errorMessage {
                        Text(err)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // Stop button
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
            // Save entry when finished
            .onChange(of: stressVM.phase) { _, newPhase in
                if newPhase == .finished, let bpm = stressVM.currentBPM {
                    let stress = stressVM.stressResult.map { String(format: "%.0f%%", $0.stressLevelPct) }
                    let entry = HeartRateEntry(bpm: bpm, date: Date(), stressLevel: stress)
                    vm.addEntry(entry)
                }
            }
            // Also save once prediction arrives (stress may arrive after phase change)
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
            .navigationTitle(stressVM.phase == .idle ? "Stress" : "")
        }
    }
}
