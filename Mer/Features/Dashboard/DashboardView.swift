import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @State private var month = Calendar.current.monthInterval(containing: .now).start

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                MonthPicker(month: $month)
                DashboardContent(month: month)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background { PaperBackground() }
    }
}

private struct DashboardContent: View {
    @Query private var entries: [Entry]
    @State private var editing: Entry?
    private let interval: DateInterval

    init(month: Date) {
        let interval = Calendar.current.monthInterval(containing: month)
        let start = interval.start
        let end = interval.end
        self.interval = interval
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
    }

    var body: some View {
        let summary = MonthSummary(entries: entries)
        VStack(spacing: 18) {
            MerSays(mood: MerMood(summary: summary))
            SpentCard(spent: summary.expense)
            if !summary.days.isEmpty {
                DailyCard(summary: summary, interval: interval)
            }
            RecentCard(entries: Array(entries.prefix(5)), editing: $editing)
        }
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }
}

private struct MerSays: View {
    let mood: MerMood

    var body: some View {
        HStack(spacing: 12) {
            MerAvatar()
            Text(mood.line)
                .font(.crayon(16, relativeTo: .callout, bold: false))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sketchyCard(fill: Palette.highlight, seed: 21, padding: 12)
        }
    }
}

private struct SpentCard: View {
    let spent: Decimal
    @Environment(\.currencyCode) private var code

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spent this month")
                .font(.crayon(15, relativeTo: .subheadline, bold: false))
                .foregroundStyle(Palette.pencil)
            Text(spent.money(code))
                .font(.crayon(38, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .sketchyCard(seed: 2)
        .animation(.snappy, value: spent)
    }
}

private struct DailyCard: View {
    let summary: MonthSummary
    let interval: DateInterval
    @State private var openDay: DayTotal?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Day by day").font(.crayon(20, relativeTo: .title3))
            Chart(summary.days) { day in
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Spent", day.expense.double))
                    .foregroundStyle(Crayon.sky.color)
                    .cornerRadius(3)
            }
            .chartXScale(domain: interval.start...interval.end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .onTapGesture { location in
                            guard let plotFrame = proxy.plotFrame,
                                let date: Date = proxy.value(atX: location.x - geometry[plotFrame].origin.x)
                            else { return }
                            openDay = summary.days.first { Calendar.current.isDate($0.day, inSameDayAs: date) }
                        }
                }
            }
            .frame(height: 160)
        }
        .foregroundStyle(Palette.ink)
        .sketchyCard(seed: 4)
        .sheet(item: $openDay) { DayEntriesSheet(day: $0.day) }
    }
}

private struct DayEntriesSheet: View {
    let day: Date
    @Query private var entries: [Entry]
    @State private var editing: Entry?
    @Environment(\.dismiss) private var dismiss

    init(day: Date) {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        self.day = start
        _entries = Query(filter: #Predicate<Entry> { $0.date >= start && $0.date < end }, sort: \Entry.date, order: .reverse)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if entries.isEmpty {
                        MerEmptyState(title: "No entries", message: "Nothing logged on this day.")
                    }
                    ForEach(entries) { entry in
                        Button {
                            editing = entry
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background { PaperBackground() }
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }
}

private struct RecentCard: View {
    let entries: [Entry]
    @Binding var editing: Entry?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent").font(.crayon(20, relativeTo: .title3))
            if entries.isEmpty {
                Text("Tap + to log your first entry.").foregroundStyle(Palette.pencil)
            }
            ForEach(entries) { entry in
                Button {
                    editing = entry
                } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Palette.ink)
        .sketchyCard(seed: 5)
    }
}

#Preview {
    DashboardView()
        .modelContainer(Store.preview)
}
