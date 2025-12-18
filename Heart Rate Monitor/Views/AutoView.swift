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
    
    // Known durations from AutoHeartRateViewModel
    private var totalForCurrentPhase: Int {
        switch autoVM.phase {
        case .measuring: return 12
        case .preview: return 10
        default: return 0
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview only during measuring
                if autoVM.phase == .measuring || autoVM.phase == .preview {
                    VStack(spacing: 0) {
                        CameraPreview(session: autoVM.session)
                            .frame(height: 160)
                            .overlay(
                                LinearGradient(gradient: Gradient(colors: [.black.opacity(0.5), .clear]),
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .clipped()
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                }
                
                VStack(spacing: 16) {
                    if autoVM.phase == .idle {
                        VStack(spacing: 16) {
                            Text("Automatic Measurement")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Measure your heart rate using your device's camera and flashlight. Simply place your fingertip over the camera lens and keep it still. The app will detect subtle color changes to calculate your heart rate.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Button {
                                autoVM.startSession()
                            } label: {
                                Text("Start Automatic Session")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red) // keep style, only color
                            .padding(.top, 8)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    } else if autoVM.phase == .measuring || autoVM.phase == .preview {
                        VStack(spacing: 16) {
                            Spacer()
                            
                            // Centered heart with circular countdown
                            HeartTimerView(
                                heartScale: autoVM.heartScale,
                                secondsLeft: autoVM.secondsLeft,
                                totalSeconds: totalForCurrentPhase,
                                heartSize: 96,
                                color: .red
                            )
                            
                            if autoVM.phase == .measuring {
                                Text("Keep fingertip on the camera")
                                    .foregroundColor(.secondary)
                            } else {
                                if let bpm = autoVM.currentBPM {
                                    Text("\(bpm) BPM")
                                        .font(.system(size: 42, weight: .bold))
                                } else {
                                    Text("Calibrating…")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                    } else if autoVM.phase == .finished {
                        VStack(spacing: 16) {
                            if let bpm = autoVM.currentBPM {
                                Text("Final Result: \(bpm) BPM")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            } else {
                                Text("No result")
                                    .foregroundColor(.secondary)
                            }
                            
                            Button("Done") {
                                // Just reset to idle state to show the explanation screen
                                autoVM.phase = .idle
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red) // keep style, only color
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
                        if autoVM.phase == .measuring || autoVM.phase == .preview {
                            Button(role: .destructive) {
                                autoVM.stopSessionEarly()
                            } label: {
                                Text("Stop")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red) // keep style, only color
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            // When session ends, save to shared history
            .onChange(of: autoVM.phase) { _, newPhase in
                if newPhase == .finished, let bpm = autoVM.currentBPM {
                    let entry = HeartRateEntry(bpm: bpm, date: Date())
                    vm.log.insert(entry, at: 0)
                    vm.saveData()
                }
            }
            .navigationTitle(autoVM.phase == .idle ? "Measurement" : "")
        }
    }
}

