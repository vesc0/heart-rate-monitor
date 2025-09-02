//
//  HistoryView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/2/25.
//

import SwiftUI

struct HistoryView: View {
    @Binding var entries: [HeartRateEntry]

    var averageBPM: Int? {
        guard !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.bpm }
        return sum / entries.count
    }

    var body: some View {
        NavigationStack {
            List {
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
                    ForEach(entries) { entry in
                        HStack {
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
                    }
                    .onDelete { offsets in
                        entries.remove(atOffsets: offsets)
                        // save back to UserDefaults immediately
                        if let encoded = try? JSONEncoder().encode(entries) {
                            UserDefaults.standard.set(encoded, forKey: "HeartRateLog")
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
