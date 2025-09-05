//
//  HistoryView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/2/25.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var vm: HeartRateViewModel
    @State private var selectedEntries = Set<HeartRateEntry.ID>()
    @State private var isSelectionMode = false

    var averageBPM: Int? {
        guard !vm.log.isEmpty else { return nil }
        let sum = vm.log.reduce(0) { $0 + $1.bpm }
        return sum / vm.log.count
    }

    var body: some View {
        NavigationStack {
            List {
                if vm.log.isEmpty {
                    VStack(spacing: 8) {
                        Text("No Records")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Records will appear here after you complete a measurement")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    if let avg = averageBPM {
                        Section {
                            HStack {
                                Text("Average of all sessions")
                                Spacer()
                                Text("\(avg) BPM")
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    Section {
                    ForEach(vm.log) { entry in
                        HStack {
                            if isSelectionMode {
                                Image(systemName: selectedEntries.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedEntries.contains(entry.id) ? .accentColor : .gray)
                            }
                            
                            Text("\(entry.bpm) BPM")
                                .fontWeight(.semibold)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(entry.date, style: .date)
                                Text(entry.date, style: .time)
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelectionMode {
                                if selectedEntries.contains(entry.id) {
                                    selectedEntries.remove(entry.id)
                                } else {
                                    selectedEntries.insert(entry.id)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        vm.log.remove(atOffsets: offsets)
                        vm.saveData()
                    }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !vm.log.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectionMode {
                        Button(action: {
                            // Remove selected entries
                            vm.log.removeAll { selectedEntries.contains($0.id) }
                            vm.saveData()
                            // Exit selection mode
                            isSelectionMode = false
                            selectedEntries.removeAll()
                        }) {
                            Text("Delete")
                                .foregroundColor(.red)
                        }
                        .disabled(selectedEntries.isEmpty)
                    } else {
                        Button(action: {
                            isSelectionMode = true
                        }) {
                            Text("Select")
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            isSelectionMode = false
                            selectedEntries.removeAll()
                        }
                    }
                }
            }
            }
        }
    }
}
