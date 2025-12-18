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
        case .preview: return 10
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
                        
                        Text("Measure your heart rate by tapping the button in rhythm with your heartbeat. Place two fingers on your neck or wrist to find your pulse, then tap for 12 seconds to get an accurate reading.")
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
                        
                        // Centered heart with circular countdown
                        HeartTimerView(
                            heartScale: vm.heartScale,
                            secondsLeft: vm.secondsLeft,
                            totalSeconds: totalForCurrentPhase,
                            heartSize: 96,
                            color: .red
                        )
                        
                        Text("Tap with your heartbeat")
                        
                        if !vm.hasTapped {
                            Text("Waiting for first tap…")
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Button("Tap") { vm.recordTap() }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .fontWeight(.bold)
                                .tint(.red) // keep style, only color
                            
                            Button("Stop") { vm.stopSession() }
                                .buttonStyle(.bordered)
                                .tint(.red) // keep style, only color
                        }
                    }

                case .preview:
                    VStack(spacing: 16) {
                        Spacer()
                        
                        HeartTimerView(
                            heartScale: vm.heartScale,
                            secondsLeft: vm.secondsLeft,
                            totalSeconds: totalForCurrentPhase,
                            heartSize: 96,
                            color: .red
                        )
                        
                        if let bpm = vm.currentBPM {
                            Text("\(bpm) BPM")
                                .font(.system(size: 42, weight: .bold))
                        } else {
                            Text("Waiting for taps…")
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Button("Tap") { vm.recordTap() }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .fontWeight(.bold)
                                .tint(.red) // keep style, only color
                            
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

