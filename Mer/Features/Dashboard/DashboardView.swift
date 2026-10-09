import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @State private var month = Period.month.interval(containing: .now).start
    @Environment(\.currencyCode) private var account

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PeriodPicker(period: .month, date: $month)
                    DashboardContent(month: month, account: account)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .paperBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .followsCurrentPeriod($month, period: .month)
    }
}

private struct DashboardContent: View {
    @Query private var entries: [Entry]
    private let month: Date
    private let interval: DateInterval

    init(month: Date, account: String) {
        self.month = month
        let interval = Period.month.interval(containing: month)
        let start = interval.start
        let end = interval.end
        self.interval = interval
        _entries = Query(
            filter: #Predicate<Entry> { $0.accountCode == account && $0.date >= start && $0.date < end },
            sort: \Entry.date,
            order: .reverse
        )
    }

    var body: some View {
        let summary = PeriodSummary(entries: entries)
        VStack(spacing: 18) {
            MerSays(mood: MerMood(summary: summary))
            SpentCard(spent: summary.expense)
            if !summary.days.isEmpty {
                DailyCard(days: summary.days, interval: interval)
            }
            RecentCard(entries: Array(entries.prefix(5)), month: month)
        }
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
    let days: [DayTotal]
    let interval: DateInterval
    @Environment(\.currencyCode) private var account
    @State private var tappedDate: Date?
    @State private var openDay: DayTotal?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Day by day").cardTitle()
            Chart(days) { day in
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Spent", day.expense.double))
                    .foregroundStyle(Crayon.sky.color)
                    .cornerRadius(3)
            }
            .chartXScale(domain: interval.start...interval.end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day(), anchor: .top)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel(anchor: .leading)
                }
            }
            .chartXSelection(value: $tappedDate)
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { proxy.selectXValue(at: $0.location.x) }
            }
            .onChange(of: tappedDate) { _, date in
                guard let date else { return }
                openDay = days.first { Calendar.current.isDate($0.day, inSameDayAs: date) }
                tappedDate = nil
            }
            .frame(height: 160)
            .id(interval)
        }
        .foregroundStyle(Palette.ink)
        .sketchyCard(seed: 4)
        .sheet(item: $openDay) { day in
            EntriesSheet(
                title: day.day.formatted(.dateTime.weekday(.wide).day().month()),
                account: account,
                interval: DateInterval(start: day.day, end: Calendar.current.date(byAdding: .day, value: 1, to: day.day) ?? day.day)
            )
        }
    }
}

private struct RecentCard: View {
    let entries: [Entry]
    let month: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").cardTitle()
                Spacer()
                if !entries.isEmpty {
                    NavigationLink("See All") { EntriesView(month: month) }
                        .font(.crayon(15, relativeTo: .subheadline))
                }
            }
            if entries.isEmpty {
                Text("Tap + to log your first entry.").foregroundStyle(Palette.pencil)
            }
            EntryList(entries: entries)
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
