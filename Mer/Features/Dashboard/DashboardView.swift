import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @State private var month = Period.month.interval(containing: .now).start
    @Environment(\.currencyCode) private var account
    @Environment(\.currentTripID) private var currentTripID
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if let trip = currentTripID.flatMap({ context.model(for: $0) as? Trip }) {
                    TripDashboard(trip: trip)
                        .toolbarVisibility(.hidden, for: .navigationBar)
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            PeriodPicker(period: .month, date: $month)
                            DashboardContent(month: month, account: account)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    .toolbarVisibility(.hidden, for: .navigationBar)
                    .searchesEntries()
                    .paperBackground()
                }
            }
        }
        .followsCurrentPeriod($month, period: .month)
    }
}

private struct DashboardContent: View {
    @Query private var entries: [Entry]
    @AppStorage(DefaultsKey.budgetEnabled) private var budgetEnabled = false
    @AppStorage(DefaultsKey.monthlyBudget) private var monthlyBudget = 0.0
    private let month: Date
    private let account: String
    private let interval: DateInterval

    init(month: Date, account: String) {
        self.month = month
        self.account = account
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
        let homeEntries = entries.filter { $0.trip == nil }
        let budgetSummary = PeriodSummary(entries: homeEntries.filter(\.countsInBudget))
        let budget = MonthlyBudget.limit(isOn: budgetEnabled, stored: monthlyBudget).map {
            BudgetProgress(limit: $0, spent: budgetSummary.expense)
        }
        let summary = budget == nil ? PeriodSummary(entries: homeEntries) : budgetSummary
        VStack(spacing: 18) {
            MerSays(mood: homeEntries.isEmpty ? .waiting : budget.map(MerMood.init(budget:)) ?? MerMood(summary: summary))
            SpentCard(title: "Spent this month", spent: summary.expense, color: budget?.level.textColor ?? Palette.ink) {
                if let budget { BudgetDetail(budget: budget) }
            }
            if !summary.days.isEmpty {
                DailyCard(days: summary.days, interval: interval, source: .account(account))
            }
            RecentCard(entries: entries) { EntriesView(month: month) }
        }
    }
}

struct MerSays: View {
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

struct SpentCard<Detail: View>: View {
    let title: LocalizedStringKey
    let spent: Decimal
    var prefix = ""
    var color = Palette.ink
    @ViewBuilder var detail: Detail
    @Environment(\.currencyCode) private var code

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.crayon(15, relativeTo: .subheadline, bold: false))
                .foregroundStyle(Palette.pencil)
            Text(verbatim: prefix + spent.money(code))
                .font(.crayon(38, relativeTo: .largeTitle))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            detail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .sketchyCard(seed: 2)
        .animation(.snappy, value: spent)
    }
}

extension SpentCard where Detail == EmptyView {
    init(title: LocalizedStringKey, spent: Decimal, prefix: String = "") {
        self.init(title: title, spent: spent, prefix: prefix) { EmptyView() }
    }
}

struct DailyCard: View {
    let days: [DayTotal]
    let interval: DateInterval
    let source: EntrySource
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
                source: source,
                interval: DateInterval(start: day.day, end: Calendar.current.date(byAdding: .day, value: 1, to: day.day) ?? day.day)
            )
        }
    }
}

struct RecentCard<SeeAll: View>: View {
    private let entries: [Entry]
    private let seeAll: SeeAll

    init(entries: [Entry], @ViewBuilder seeAll: () -> SeeAll) {
        self.entries = Array(entries.sorted { ($0.createdAt ?? $0.date, $0.date) > ($1.createdAt ?? $1.date, $1.date) }.prefix(5))
        self.seeAll = seeAll()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").cardTitle()
                Spacer()
                if !entries.isEmpty {
                    NavigationLink("See All") { seeAll }
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
