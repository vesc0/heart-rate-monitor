//
//  AutoView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/3/25.
//

import SwiftUI

struct AutoView: View {
    // Main view model for shared history
    @ObservedObject var vm: HeartRateViewModel
    // Local view model for camera-based heart rate detection
    @StateObject private var autoVM = AutoHeartRateViewModel()

    var body: some View {
        ZStack {
            // Camera preview behind content (small header-style strip)
            VStack(spacing: 0) {
                if autoVM.phase != .idle {
                    CameraPreview(session: autoVM.session)
                        .frame(height: 160)
                        .overlay(
                            LinearGradient(gradient: Gradient(colors: [.black.opacity(0.5), .clear]),
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .clipped()
                } else {
                    Color.clear.frame(height: 16)
                }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                // HEART at top – always visible during a session
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundColor(.red)
                    .scaleEffect(autoVM.heartScale)
                    .padding(.top, 32)

                // Status / BPM
                if autoVM.phase == .measuring {
                    Text("Measuring… keep fingertip on the camera")
                        .foregroundColor(.secondary)
                    Text("\(autoVM.secondsLeft)s left")
                        .foregroundColor(.secondary)
                } else if autoVM.phase == .preview {
                    if let bpm = autoVM.currentBPM {
                        Text("\(bpm) BPM")
                            .font(.system(size: 42, weight: .bold))
                    } else {
                        Text("Calibrating…")
                            .foregroundColor(.secondary)
                    }
                    Text("\(autoVM.secondsLeft)s left")
                        .foregroundColor(.secondary)
                } else if autoVM.phase == .finished {
                    if let bpm = autoVM.currentBPM {
                        Text("Final: \(bpm) BPM")
                            .font(.title2)
                            .padding(.top, 8)
                    } else {
                        Text("No result")
                            .foregroundColor(.secondary)
                    }
                }

                if let err = autoVM.errorMessage {
                    Text(err).foregroundColor(.red).multilineTextAlignment(.center)
                }

                Spacer()

                // Bottom-fixed button (UX consistency with Manual)
                Group {
                    switch autoVM.phase {
                    case .idle, .finished:
                        Button {
                            autoVM.startSession()
                        } label: {
                            Text("Start Automatic Session")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                    case .measuring, .preview:
                        Button(role: .destructive) {
                            autoVM.stopSessionEarly()
                        } label: {
                            Text("Stop")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding([.horizontal, .bottom])
        }
        // When session ends, save to shared history
        .onChange(of: autoVM.phase) { old, newPhase in
            if newPhase == .finished, let bpm = autoVM.currentBPM {
                let entry = HeartRateEntry(bpm: bpm, date: Date())
                vm.log.insert(entry, at: 0)
                vm.saveData()
            }
        }
        .navigationTitle("Automatic")
    }
}
