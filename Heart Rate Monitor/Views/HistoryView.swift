//
//  HistoryView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/2/25.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var vm: HeartRateViewModel
    @State private var selectedEntries = Set<HeartRateEntry.ID>()
    @State private var isSelectionMode = false
    @State private var rangeMode: RangeMode = .weekly
    @State private var visibleCount: Int = 5
    
    // Paging offsets
    @State private var weekOffset: Int = 0    // 0 = current week, -1 = previous week
    @State private var monthOffset: Int = 0   // 0 = current month, -1 = previous month
    
    // Calendar helpers
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    private var todayStart: Date { calendar.startOfDay(for: Date()) }
    
    // MARK: - Seed sample data (debug/demo)
    private var shouldSeed: Bool {
        vm.log.isEmpty
    }
    
    private func seedSampleDataIfNeeded() {
        guard shouldSeed else { return }
        var entries: [HeartRateEntry] = []
        
        // Generate ~4.5 months of daily data with 1-3 measurements per day
        let daysBack = 135
        for d in 0..<daysBack {
            guard let dayDate = calendar.date(byAdding: .day, value: -d, to: todayStart) else { continue }
            let count = Int.random(in: 1...3)
            // Create plausible BPMs per day around a baseline that drifts slowly
            let baseline = 68 + Int(6 * sin(Double(d) / 9.0)) // mild variation
            for i in 0..<count {
                let bpm = max(45, min(160, baseline + Int.random(in: -12...14)))
                // Spread times across the day
                let hour = [9, 14, 20].randomElement() ?? 12
                let minute = Int.random(in: 0..<60)
                var comps = calendar.dateComponents([.year, .month, .day], from: dayDate)
                comps.hour = hour + i
                comps.minute = minute
                let ts = calendar.date(from: comps) ?? dayDate
                entries.append(HeartRateEntry(bpm: bpm, date: ts))
            }
        }
        // Sort newest first to match existing UI expectations
        entries.sort { $0.date > $1.date }
        vm.log = entries
        vm.saveData()
    }
    
    // MARK: - Aggregations
    private var dailyRangesAll: [DailyBPMRange] {
        let grouped = Dictionary(grouping: vm.log) { entry in
            calendar.startOfDay(for: entry.date)
        }
        .map { (dayStart, entries) -> DailyBPMRange in
            let minBPM = entries.map(\.bpm).min() ?? 0
            let maxBPM = entries.map(\.bpm).max() ?? 0
            return DailyBPMRange(day: dayStart, min: minBPM, max: maxBPM)
        }
        .sorted { $0.day < $1.day }
        return grouped
    }
    
    // MARK: - Period computations
    private var currentWeekRange: (start: Date, end: Date) {
        // Find Monday of the week for today, then apply offset in weeks
        let weekday = calendar.component(.weekday, from: todayStart) // 1=Sun…7=Sat
        let daysFromMonday = (weekday == 1) ? 6 : (weekday - 2) // Sun->6, Mon->0, Tue->1, ...
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart) ?? todayStart
        let start = calendar.date(byAdding: .day, value: weekOffset * 7, to: monday) ?? monday
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }
    
    private var weekDays: [Date] {
        let (start, _) = currentWeekRange
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    private var currentMonthStart: Date {
        let comps = calendar.dateComponents([.year, .month], from: todayStart)
        let startOfCurrent = calendar.date(from: comps) ?? todayStart
        return calendar.date(byAdding: .month, value: monthOffset, to: startOfCurrent) ?? startOfCurrent
    }
    
    private var currentMonthRange: (start: Date, end: Date) {
        let start = currentMonthStart
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        return (start, end)
    }
    
    private var monthDays: [Date] {
        let (start, end) = currentMonthRange
        var days: [Date] = []
        var cur = start
        while cur <= end {
            days.append(cur)
            cur = calendar.date(byAdding: .day, value: 1, to: cur) ?? cur.addingTimeInterval(86400)
        }
        return days
    }
    
    private var dailyRangesForCurrentWeek: [DailyBPMRange] {
        let dict = Dictionary(uniqueKeysWithValues: dailyRangesAll.map { ($0.day, $0) })
        return weekDays.compactMap { dict[$0] }
    }
    
    private var dailyRangesForCurrentMonth: [DailyBPMRange] {
        let dict = Dictionary(uniqueKeysWithValues: dailyRangesAll.map { ($0.day, $0) })
        return monthDays.compactMap { dict[$0] }
    }
    
    // Paged measurements slice
    private var pagedLog: ArraySlice<HeartRateEntry> {
        let end = min(visibleCount, vm.log.count)
        return vm.log.prefix(end)
    }
    
    private var hasMore: Bool {
        visibleCount < vm.log.count
    }
    
    // Average across all sessions
    var averageBPM: Int? {
        guard !vm.log.isEmpty else { return nil }
        let sum = vm.log.reduce(0) { $0 + $1.bpm }
        return sum / vm.log.count
    }
    
    // MARK: - Titles
    private var periodTitle: String {
        switch rangeMode {
        case .weekly:
            let (start, end) = currentWeekRange
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            let yearFmt = DateFormatter()
            yearFmt.dateFormat = "yyyy"
            let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
            let title = "\(fmt.string(from: start)) – \(fmt.string(from: end))" + (sameYear ? ", \(yearFmt.string(from: end))" : "")
            return title
        case .monthly:
            let fmt = DateFormatter()
            fmt.dateFormat = "LLLL yyyy" // e.g., September 2025
            return fmt.string(from: currentMonthStart)
        }
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
                        
                        // Seed button for demo
                        Button("Load Demo Data") {
                            seedSampleDataIfNeeded()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    // Range selector + header with navigation
                    Section {
                        // Segmented control
                        Picker("Range", selection: $rangeMode) {
                            Text("Weekly").tag(RangeMode.weekly)
                            Text("Monthly").tag(RangeMode.monthly)
                        }
                        .pickerStyle(.segmented)
                        
                        // Header with period title and navigation
                        HStack {
                            Button {
                                withAnimation(.easeInOut) {
                                    if rangeMode == .weekly { weekOffset -= 1 }
                                    else { monthOffset -= 1 }
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Text(periodTitle)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeInOut) {
                                    if rangeMode == .weekly {
                                        weekOffset = min(0, weekOffset + 1)
                                    } else {
                                        monthOffset = min(0, monthOffset + 1)
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.plain)
                            .disabled(rangeMode == .weekly ? weekOffset == 0 : monthOffset == 0)
                            .opacity((rangeMode == .weekly ? weekOffset == 0 : monthOffset == 0) ? 0.4 : 1)
                        }
                        .padding(.top, 4)
                        
                        // Prepare data
                        let baseData: [DailyBPMRange] = (rangeMode == .weekly) ? dailyRangesForCurrentWeek : dailyRangesForCurrentMonth
                        let chartData: [DailyBPMRange] = baseData.filter { $0.min != 0 || $0.max != 0 }
                        
                        // Chart
                        Chart(chartData) { day in
                            RuleMark(
                                x: .value("Day", day.day),
                                yStart: .value("Min BPM", day.min),
                                yEnd: .value("Max BPM", day.max)
                            )
                            .foregroundStyle(Color.red)
                            // Thicker line for weekly view, default for monthly
                            .lineStyle(StrokeStyle(lineWidth: rangeMode == .weekly ? 10 : 6, lineCap: .round))
                        }
                        // X Axis formatting
                        .chartXAxis {
                            if rangeMode == .weekly {
                                AxisMarks(values: weekDays) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let dateValue = value.as(Date.self) {
                                        AxisValueLabel(weekdayInitialMonFirst(for: dateValue))
                                    }
                                }
                            } else {
                                AxisMarks(values: monthDays) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    if let dateValue = value.as(Date.self) {
                                        let day = calendar.component(.day, from: dateValue)
                                        AxisValueLabel(String(format: "%02d", day))
                                    }
                                }
                            }
                        }
                        // Y axis on the right without label text
                        .chartYAxis {
                            AxisMarks(position: .trailing)
                        }
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    } header: {
                        Text(rangeMode == .weekly ? "Daily Range (Weekly)" : "Daily Range (Monthly)")
                    }
                    
                    if let avg = averageBPM {
                        Section {
                            HStack {
                                Text("Average of all sessions")
                                Spacer()
                                Text("\(avg) BPM")
                                    .fontWeight(.semibold)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    
                    // Measurements as a proper section with header style matching "Daily Range"
                    Section {
                        // Rows
                        ForEach(pagedLog) { entry in
                            HStack(spacing: 12) {
                                if isSelectionMode {
                                    Image(systemName: selectedEntries.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedEntries.contains(entry.id) ? .accentColor : .gray)
                                }
                                
                                Text("\(entry.bpm) BPM")
                                    .fontWeight(.semibold)
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 2) {
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
                            visibleCount = min(visibleCount, vm.log.count)
                        }
                        
                        if hasMore {
                            Button {
                                visibleCount = min(visibleCount + 5, vm.log.count)
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Show more")
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Measurements")
                            Spacer()
                            if isSelectionMode {
                                Button("Cancel") {
                                    isSelectionMode = false
                                    selectedEntries.removeAll()
                                }
                                .buttonStyle(.plain)
                                
                                Button("Select All") {
                                    // Select ALL entries (not just visible)
                                    let ids = vm.log.map(\.id)
                                    selectedEntries = Set(ids)
                                }
                                .buttonStyle(.plain)
                                
                                Button("Delete") {
                                    vm.log.removeAll { selectedEntries.contains($0.id) }
                                    vm.saveData()
                                    isSelectionMode = false
                                    selectedEntries.removeAll()
                                    // Adjust visible count if needed
                                    visibleCount = min(visibleCount, vm.log.count)
                                }
                                .foregroundColor(.red)
                                .disabled(selectedEntries.isEmpty)
                            } else {
                                Button("Select") {
                                    isSelectionMode = true
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    // Match the same insets as the chart section so the header-to-content spacing matches
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }
            .navigationTitle("History")
        }
        .onAppear {
            seedSampleDataIfNeeded()
        }
        .onChange(of: vm.log) { _, _ in
            // Reset pagination if list shrinks a lot
            visibleCount = min(max(5, visibleCount), vm.log.count)
            // If selection contains deleted IDs, clean it up
            selectedEntries = selectedEntries.filter { id in vm.log.contains(where: { $0.id == id }) }
        }
        // Reset forward navigation disablement when switching modes
        .onChange(of: rangeMode) { _, newMode in
            if newMode == .weekly {
                weekOffset = 0
            } else {
                monthOffset = 0
            }
        }
    }
}

// MARK: - Helpers

private enum RangeMode: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    var id: String { rawValue }
}

private struct DailyBPMRange: Identifiable {
    var id: Date { day }
    let day: Date
    let min: Int
    let max: Int
}

private extension HistoryView {
    // Return M T W T F S S (Mon-first) for the given date
    func weekdayInitialMonFirst(for date: Date) -> String {
        // Map calendar weekday (1=Sun…7=Sat) into Mon-first symbols
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        let weekday = calendar.component(.weekday, from: date) // 1..7
        // Convert to 0..6 with Monday=0
        let monFirstIndex = (weekday + 5) % 7 // Sun(1)->6, Mon(2)->0, Tue(3)->1, ...
        return symbols[monFirstIndex]
    }
}
