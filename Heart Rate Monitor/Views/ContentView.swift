//
//  ContentView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = HeartRateViewModel()
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Manual Heart Rate Monitor")
                    .font(.title)
                    .padding(.top)

                switch vm.phase {
                case .idle:
                    Text("Press Start to begin")
                        .foregroundColor(.gray)

                    Button("Start Session") {
                        vm.startSession()
                    }
                    .buttonStyle(.borderedProminent)

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
                        Button("Tap") { vm.recordTap() }
                            .buttonStyle(.bordered)
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
                        Button("Tap") { vm.recordTap() }
                            .buttonStyle(.bordered)
                    }

                case .finished:
                    if let bpm = vm.currentBPM {
                        Text("Final Result: \(bpm) BPM")
                            .font(.title2)
                    } else {
                        Text("No data recorded")
                    }

                    Button("Start New Session") {
                        vm.startNewSession()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                if let latest = vm.log.first {
                    Divider()
                    HStack {
                        Text("Last saved:")
                        Spacer()
                        Text("\(latest.bpm) BPM")
                        Text(latest.date, style: .time)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("History") { showHistory = true }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(entries: $vm.log)
            }
        }
    }
}

#Preview {
    ContentView()
}
