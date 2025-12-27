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
    
    // Selection for filtering the list
    @State private var selectedDay: Date? = nil
    
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
            let avgBPM: Int = {
                guard !entries.isEmpty else { return 0 }
                let sum = entries.reduce(0) { $0 + $1.bpm }
                return sum / entries.count
            }()
            return DailyBPMRange(day: dayStart, min: minBPM, max: maxBPM, avg: avgBPM)
        }
        .sorted { $0.day < $1.day }
        return grouped
    }
    
    // MARK: - Period computations
    private var currentWeekRange: (start: Date, end: Date) {
        let weekday = calendar.component(.weekday, from: todayStart)
        let daysFromMonday = (weekday == 1) ? 6 : (weekday - 2)
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
    
    // Period stats (min/avg/max) for the visible week/month
    private var weekStats: PeriodStats? {
        let days = dailyRangesForCurrentWeek
        return aggregateStats(for: days)
    }
    private var monthStats: PeriodStats? {
        let days = dailyRangesForCurrentMonth
        return aggregateStats(for: days)
    }
    private func aggregateStats(for days: [DailyBPMRange]) -> PeriodStats? {
        guard !days.isEmpty else { return nil }
        let dayMins = days.map(\.min).filter { $0 > 0 }
        let dayMaxs = days.map(\.max).filter { $0 > 0 }
        let dayAvgs = days.map(\.avg).filter { $0 > 0 }
        guard !dayMins.isEmpty, !dayMaxs.isEmpty, !dayAvgs.isEmpty else { return nil }
        let minVal = dayMins.min() ?? 0
        let maxVal = dayMaxs.max() ?? 0
        let avgVal = dayAvgs.reduce(0, +) / dayAvgs.count
        return PeriodStats(min: minVal, avg: avgVal, max: maxVal)
    }
    
    // Stats to display (respects selected day on weekly)
    private var displayStats: PeriodStats? {
        switch rangeMode {
        case .weekly:
            if let sel = selectedDay {
                // Stats for the selected single day
                if let day = dailyRangesAll.first(where: { calendar.isDate($0.day, inSameDayAs: sel) }) {
                    return PeriodStats(min: day.min, avg: day.avg, max: day.max)
                } else {
                    return nil
                }
            } else {
                return weekStats
            }
        case .monthly:
            return monthStats
        }
    }
    
    // Measurements filtering based on selection and current period
    private var filteredMeasurements: [HeartRateEntry] {
        switch rangeMode {
        case .weekly:
            let (start, end) = currentWeekRange
            if let sel = selectedDay {
                let startSel = sel
                let endSel = sel.addingTimeInterval(24 * 60 * 60 - 1)
                return vm.log.filter { $0.date >= startSel && $0.date <= endSel }
            } else {
                return vm.log.filter { $0.date >= start && $0.date <= end.addingTimeInterval(24*60*60 - 1) }
            }
        case .monthly:
            let (start, end) = currentMonthRange
            return vm.log.filter { $0.date >= start && $0.date <= end.addingTimeInterval(24*60*60 - 1) }
        }
    }
    
    private var pagedLog: ArraySlice<HeartRateEntry> {
        let end = min(visibleCount, filteredMeasurements.count)
        return filteredMeasurements.sorted { $0.date > $1.date }.prefix(end)
    }
    
    private var hasMore: Bool {
        visibleCount < filteredMeasurements.count
    }
    
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
            fmt.dateFormat = "LLLL yyyy"
            return fmt.string(from: currentMonthStart)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
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
                        
                        Button("Load Demo Data") {
                            seedSampleDataIfNeeded()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
                } else {
                    List {
                        Section {
                            Picker("Range", selection: $rangeMode) {
                                Text("Weekly").tag(RangeMode.weekly)
                                Text("Monthly").tag(RangeMode.monthly)
                            }
                            .pickerStyle(.segmented)
                            
                            HStack {
                                Button {
                                    withAnimation(.easeInOut) {
                                        if rangeMode == .weekly { weekOffset -= 1 }
                                        else { monthOffset -= 1 }
                                        selectedDay = nil
                                        visibleCount = min(visibleCount, filteredMeasurements.count)
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
                                        selectedDay = nil
                                        visibleCount = min(visibleCount, filteredMeasurements.count)
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .buttonStyle(.plain)
                                .disabled(rangeMode == .weekly ? weekOffset == 0 : monthOffset == 0)
                                .opacity((rangeMode == .weekly ? weekOffset == 0 : monthOffset == 0) ? 0.4 : 1)
                            }
                            .padding(.top, 4)
                            
                            let baseData: [DailyBPMRange] = (rangeMode == .weekly) ? dailyRangesForCurrentWeek : dailyRangesForCurrentMonth
                            let chartData: [DailyBPMRange] = baseData.filter { $0.min != 0 || $0.max != 0 }
                            
                            Chart(chartData) { day in
                                ChartBar(
                                    day: day,
                                    rangeMode: rangeMode,
                                    isSelected: isSelected(day),
                                    hasSelection: selectedDay != nil,
                                    labelProvider: { dayLabel(for: day.day) }
                                )
                            }
                            // Precise tap handling: only near a day’s line (weekly only)
                            .chartOverlay { proxy in
                                if rangeMode == .weekly {
                                    GeometryReader { _ in
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onEnded { value in
                                                        guard let tappedDate: Date = proxy.value(atX: value.location.x) else { return }
                                                        let dayStart = calendar.startOfDay(for: tappedDate)
                                                        guard let dayData = dailyRangesForCurrentWeek.first(where: { calendar.isDate($0.day, inSameDayAs: dayStart) }) else { return }
                                                        guard let dayX: CGFloat = proxy.position(forX: dayData.day) else { return }
                                                        let dx = abs(dayX - value.location.x)
                                                        let xHitSlop: CGFloat = 18
                                                        guard dx <= xHitSlop else { return }
                                                        guard
                                                            let yMin: CGFloat = proxy.position(forY: Double(dayData.min)),
                                                            let yMax: CGFloat = proxy.position(forY: Double(dayData.max))
                                                        else { return }
                                                        let yLow = min(yMin, yMax)
                                                        let yHigh = max(yMin, yMax)
                                                        let yPadding: CGFloat = 14
                                                        let yHit = (value.location.y >= (yLow - yPadding)) && (value.location.y <= (yHigh + yPadding))
                                                        guard yHit else { return }
                                                        toggleSelection(for: dayData.day)
                                                    }
                                            )
                                    }
                                }
                            }
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
                                            let dayNum = calendar.component(.day, from: dateValue)
                                            if [1, 10, 20, 30].contains(dayNum) {
                                                AxisValueLabel(String(dayNum))
                                            } else {
                                                AxisValueLabel("")
                                            }
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .trailing)
                            }
                            .frame(height: 240)
                            .padding(.bottom, 6)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        } header: {
                            Text("Daily Range")
                        } footer: {
                            if let stats = displayStats {
                                VStack(spacing: 10) {
                                    HStack(spacing: 18) {
                                        statPillLarge(title: "Min", value: stats.min)
                                        statPillLarge(title: "Avg", value: stats.avg)
                                        statPillLarge(title: "Max", value: stats.max)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 10)
                                .padding(.bottom, 14)
                            }
                        }
                        
                        Section {
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
                                        // Shorter date format: "Dec 27, 2025"
                                        Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
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
                                let sortedFiltered = filteredMeasurements.sorted { $0.date > $1.date }
                                let toDelete = offsets.map { sortedFiltered[$0] }
                                vm.log.removeAll { e in toDelete.contains(e) }
                                vm.saveData()
                                visibleCount = min(visibleCount, filteredMeasurements.count)
                            }
                            
                            if hasMore {
                                Button {
                                    visibleCount = min(visibleCount + 5, filteredMeasurements.count)
                                } label: {
                                    HStack {
                                        Spacer()
                                        Text("Show more")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }
                        } header: {
                            HStack {
                                Text(measurementsHeaderTitle)
                                Spacer()
                                if isSelectionMode {
                                    Button("Cancel") {
                                        isSelectionMode = false
                                        selectedEntries.removeAll()
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button("Select All") {
                                        let ids = filteredMeasurements.map(\.id)
                                        selectedEntries = Set(ids)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button("Delete") {
                                        vm.log.removeAll { selectedEntries.contains($0.id) }
                                        vm.saveData()
                                        isSelectionMode = false
                                        selectedEntries.removeAll()
                                        visibleCount = min(visibleCount, filteredMeasurements.count)
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
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                }
            }
            .navigationTitle("History")
        }
        .onAppear {
            seedSampleDataIfNeeded()
        }
        .onChange(of: vm.log) { _, _ in
            visibleCount = min(max(5, visibleCount), filteredMeasurements.count)
            selectedEntries = selectedEntries.filter { id in vm.log.contains(where: { $0.id == id }) }
        }
        .onChange(of: rangeMode) { _, newMode in
            if newMode == .weekly {
                weekOffset = 0
                selectedDay = nil
            } else {
                monthOffset = 0
                selectedDay = nil
            }
            visibleCount = min(visibleCount, filteredMeasurements.count)
        }
    }
}

// MARK: - Helpers

private enum RangeMode: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    var id: String { rawValue }
}

private struct DailyBPMRange: Identifiable, Equatable {
    var id: Date { day }
    let day: Date
    let min: Int
    let max: Int
    let avg: Int
}

private struct PeriodStats {
    let min: Int
    let avg: Int
    let max: Int
}

private extension HistoryView {
    func weekdayInitialMonFirst(for date: Date) -> String {
        let symbols = ["M", "T", "W", "T", "F", "S", "S"]
        let weekday = calendar.component(.weekday, from: date)
        let monFirstIndex = (weekday + 5) % 7
        return symbols[monFirstIndex]
    }
    
    func isSelected(_ day: DailyBPMRange) -> Bool {
        guard let s = selectedDay else { return false }
        return calendar.isDate(s, inSameDayAs: day.day)
    }
    
    func toggleSelection(for date: Date) {
        if let s = selectedDay, calendar.isDate(s, inSameDayAs: date) {
            selectedDay = nil
        } else {
            selectedDay = date
        }
        visibleCount = min(max(5, visibleCount), filteredMeasurements.count)
    }
    
    func dayLabel(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE d"
        return df.string(from: date)
    }
    
    var measurementsHeaderTitle: String {
        switch rangeMode {
        case .weekly:
            let (start, end) = currentWeekRange
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            let yearFmt = DateFormatter(); yearFmt.dateFormat = "yyyy"
            let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
            let rangeStr = "\(df.string(from: start)) – \(df.string(from: end))" + (sameYear ? ", \(yearFmt.string(from: end))" : "")
            if let s = selectedDay {
                let d = DateFormatter(); d.dateStyle = .medium
                return "Measurements – \(d.string(from: s))"
            } else {
                return "Measurements – \(rangeStr)"
            }
        case .monthly:
            let df = DateFormatter()
            df.dateFormat = "LLLL yyyy"
            return "Measurements – \(df.string(from: currentMonthStart))"
        }
    }
    
    @ViewBuilder
    func statPillLarge(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value) BPM")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}

// MARK: - Small helper view to keep Chart closure simple

private struct ChartBar: ChartContent {
    let day: DailyBPMRange
    let rangeMode: RangeMode
    let isSelected: Bool
    let hasSelection: Bool
    let labelProvider: () -> String
    
    var body: some ChartContent {
        let width: CGFloat = rangeMode == .weekly ? (isSelected ? 18 : 14) : 6
        let color: Color = isSelected ? .red : Color.red.opacity(0.85)
        let alpha: Double = (rangeMode == .weekly && hasSelection) ? (isSelected ? 1.0 : 0.35) : 1.0
        
        RuleMark(
            x: .value("Day", day.day),
            yStart: .value("Min BPM", day.min),
            yEnd: .value("Max BPM", day.max)
        )
        .foregroundStyle(color)
        .lineStyle(StrokeStyle(lineWidth: width, lineCap: .round))
        .opacity(alpha)
        .accessibilityLabel(Text("\(labelProvider()): \(day.min)–\(day.max) BPM"))
    }
}
