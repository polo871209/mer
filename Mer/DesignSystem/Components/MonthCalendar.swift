import SwiftData
import SwiftUI

struct MonthCalendar: View {
    let selection: Date?
    let pick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var account
    @State private var month: Date
    @State private var height: CGFloat = 440
    private let calendar = Calendar.current

    init(month: Date, selection: Date?, pick: @escaping (Date) -> Void) {
        self.selection = selection
        self.pick = pick
        _month = State(initialValue: Period.month.interval(containing: month).start)
    }

    var body: some View {
        VStack(spacing: 12) {
            PeriodPicker(period: .month, date: $month, allowsFuture: true)
            weekdayHeader
            DayGrid(account: account, month: month, selection: selection, pick: choose)
                .swipesPeriod(.month, date: $month, allowsFuture: true)
            Button("Today") { choose(calendar.startOfDay(for: .now)) }
                .font(.crayon(17, relativeTo: .body))
                .buttonStyle(.glass)
        }
        .padding()
        .padding(.top, 8)
        .foregroundStyle(Palette.ink)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            height = $0
        }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground { PaperBackground() }
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack(spacing: 0) {
            ForEach(ordered.indices, id: \.self) { index in
                Text(ordered[index])
                    .font(.crayon(13, relativeTo: .caption, bold: false))
                    .foregroundStyle(Palette.pencil)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func choose(_ day: Date) {
        pick(day)
        Haptics.picked()
        dismiss()
    }
}

private struct DayGrid: View {
    let month: Date
    let selection: Date?
    let pick: (Date) -> Void
    @Query private var entries: [Entry]
    private let calendar = Calendar.current

    init(account: String, month: Date, selection: Date?, pick: @escaping (Date) -> Void) {
        let interval = Period.month.interval(containing: month)
        let start = interval.start
        let end = interval.end
        self.month = month
        self.selection = selection
        self.pick = pick
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.accountCode == account && $0.date >= start && $0.date < end })
        descriptor.propertiesToFetch = [\.date]
        _entries = Query(descriptor)
    }

    var body: some View {
        let cells = monthCells
        let today = calendar.startOfDay(for: .now)
        let entryDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        Grid(horizontalSpacing: 0, verticalSpacing: 4) {
            ForEach(0..<6, id: \.self) { week in
                GridRow {
                    ForEach(0..<7, id: \.self) { weekday in
                        if let day = cells[week * 7 + weekday] {
                            DayCell(
                                day: day,
                                isToday: day == today,
                                isSelected: selection.map { calendar.isDate(day, inSameDayAs: $0) } ?? false,
                                hasEntries: entryDays.contains(day)
                            ) { pick(day) }
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    private var monthCells: [Date?] {
        guard let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let leading = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let dates = days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        let cells: [Date?] = Array(repeating: nil, count: leading) + dates
        return cells + Array(repeating: nil, count: 42 - cells.count)
    }
}

private struct DayCell: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let hasEntries: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(day.formatted(.dateTime.day()))
                .font(.crayon(18, relativeTo: .body, bold: isToday || isSelected))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if isSelected {
                        CrayonFill(color: Crayon.butter.color, shape: SketchyEllipse(seed: seed), seed: seed)
                            .frame(width: 40, height: 40)
                    }
                }
                .overlay {
                    if isToday && !isSelected {
                        SketchyEllipse(seed: seed).stroke(Palette.ink, lineWidth: 1.5).frame(width: 40, height: 40)
                    }
                }
                .overlay(alignment: .bottom) {
                    if hasEntries {
                        Circle()
                            .fill(Crayon.tangerine.color)
                            .frame(width: 5, height: 5)
                            .offset(y: -3)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasEntries ? Text("Has entries") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var seed: UInt64 {
        UInt64(Calendar.current.component(.day, from: day)) &* 31
    }
}
