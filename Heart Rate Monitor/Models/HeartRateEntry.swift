//
//  HeartrateEntry.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/2/25.
//

import Foundation

struct HeartRateEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let bpm: Int
    let date: Date
    let stressLevel: String?  // e.g. "Stressed", "Not Stressed", nil for regular measurements

    // convenience initializer for new entries
    init(bpm: Int, date: Date, id: UUID = UUID(), stressLevel: String? = nil) {
        self.id = id
        self.bpm = bpm
        self.date = date
        self.stressLevel = stressLevel
    }

    private enum CodingKeys: String, CodingKey { case id, bpm, date, stressLevel }

    // custom decode to keep compatibility if older entries lack stressLevel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bpm = try c.decode(Int.self, forKey: .bpm)
        date = try c.decode(Date.self, forKey: .date)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        stressLevel = try? c.decode(String.self, forKey: .stressLevel)
    }
}
