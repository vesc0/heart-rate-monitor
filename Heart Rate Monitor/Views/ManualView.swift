//
//  ContentView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/1/25.
//

import SwiftUI

struct ManualView: View {
    @ObservedObject var vm: HeartRateViewModel
    
    // Known durations from HeartRateViewModel
    private var totalForCurrentPhase: Int {
        switch vm.phase {
        case .measuring: return 12
        default: return 0
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch vm.phase {
                case .idle:
                    VStack(spacing: 16) {
                        Text("Manual Measurement")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Measure your heart rate by tapping the heart in rhythm with your heartbeat. Place two fingers on your neck or wrist to find your pulse, then tap for 12 seconds to get an accurate reading.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Start Manual Session") {
                            vm.startSession()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red) // keep style, only color
                        .padding(.top, 8)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)

                case .measuring:
                    VStack(spacing: 16) {
                        Spacer()
                        
                        // Tappable heart with circular countdown
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
                        
                        VStack(spacing: 20) {
                            // No Tap button; heart is tappable
                            Button("Stop") { vm.stopSession() }
                                .buttonStyle(.bordered)
                                .tint(.red) // keep style, only color
                        }
                    }

                case .finished:
                    VStack(spacing: 16) {
                        if let bpm = vm.currentBPM {
                            Text("Final Result: \(bpm) BPM")
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text("No data recorded")
                                .foregroundColor(.secondary)
                        }

                        Button("Done") {
                            vm.startNewSession()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red) // keep style, only color
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(vm.phase == .idle ? "Measurement" : "")
        }
    }
}

