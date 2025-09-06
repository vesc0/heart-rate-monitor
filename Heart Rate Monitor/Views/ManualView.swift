//
//  ContentView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/1/25.
//

import SwiftUI

struct ManualView: View {
    @ObservedObject var vm: HeartRateViewModel

    var body: some View {
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
                    .padding(.top, 8)
                }
                .frame(maxHeight: .infinity, alignment: .center)

            case .measuring:
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .foregroundColor(.red)
                        .scaleEffect(vm.heartScale)

                    Text("Tap with your heartbeat")
                    if !vm.hasTapped {
                        Text("Waiting for first tap…")
                            .foregroundColor(.gray)
                    } else {
                        Text("\(vm.secondsLeft)s left")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(spacing: 20) {
                        Button("Tap") { vm.recordTap() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .fontWeight(.bold)
                        Button("Stop") { vm.stopSession() }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                    }
                }

            case .preview:
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .foregroundColor(.red)
                        .scaleEffect(vm.heartScale)

                    if let bpm = vm.currentBPM {
                        Text("\(bpm) BPM")
                            .font(.system(size: 42, weight: .bold))
                    } else {
                        Text("Waiting for taps…")
                            .foregroundColor(.gray)
                    }
                    Text("\(vm.secondsLeft)s left")
                        .foregroundColor(.gray)
                    Spacer()
                    VStack(spacing: 20) {
                        Button("Tap") { vm.recordTap() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .fontWeight(.bold)
                        Button("Stop") { vm.stopSession() }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
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
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }

            Spacer()
        }
        .padding()
    }
}
