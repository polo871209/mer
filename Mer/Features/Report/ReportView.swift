import Charts
import SwiftData
import SwiftUI

struct ReportTab: View {
    @Environment(\.currentTripID) private var currentTripID
    @Environment(\.modelContext) private var context

    var body: some View {
        if let trip = currentTripID.flatMap({ context.model(for: $0) as? Trip }) {
            TripReportView(trip: trip)
        } else {
            ReportView()
        }
    }
}

struct ReportView: View {
    @State private var period = Period.month
    @State private var date = Date.now
    @Environment(\.currencyCode) private var account

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 14) {
                    Picker("Period", selection: $period.animation(.snappy)) {
                        ForEach(Period.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    PeriodPicker(period: period, date: $date)
                }
                .padding(.horizontal)
                ReportContent(account: account, period: period, date: $date)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .paperBackground()
        .followsCurrentPeriod($date, period: period)
    }
}

private enum ReportPage: CaseIterable, Identifiable {
    case categories, trend

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .categories: "Categories"
        case .trend: "Trend"
        }
    }
}

private struct ReportContent: View {
    let account: String
    let period: Period
    @Binding var date: Date
    let interval: DateInterval
    @Query private var entries: [Entry]
    @State private var page: ReportPage? = .categories
    @State private var pageHeights: [ReportPage: CGFloat] = [:]

    init(account: String, period: Period, date: Binding<Date>) {
        let interval = period.interval(containing: date.wrappedValue)
        let start = interval.start
        let end = interval.end
        self.account = account
        self.period = period
        _date = date
        self.interval = interval
        _entries = Query(
            filter: #Predicate<Entry> { $0.accountCode == account && $0.date >= start && $0.date < end && $0.trip == nil },
            sort: \Entry.date
        )
    }

    var body: some View {
        let summary = PeriodSummary(entries: entries)
        VStack(spacing: 14) {
            TotalsCard(summary: summary)
                .swipesPeriod(period, date: $date)
                .padding(.horizontal)
            PageDots(page: $page)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(ReportPage.allCases) { item in
                        Group {
                            switch item {
                            case .categories:
                                CategoryPage(summary: summary, source: .account(account), interval: interval)
                            case .trend:
                                TrendPage(account: account, period: period, interval: interval, spent: summary.expense)
                            }
                        }
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) {
                            $0.size.height
                        } action: {
                            pageHeights[item] = $0
                        }
                        .containerRelativeFrame(.horizontal)
                        .id(item)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: page.flatMap { pageHeights[$0] }, alignment: .top)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .animation(.snappy, value: page)
        }
    }
}

private struct TripReportView: View {
    let trip: Trip
    @Environment(\.currencyCode) private var code

    var body: some View {
        let summary = PeriodSummary(entries: trip.entries ?? [], convertingTo: code)
        ScrollView {
            VStack(spacing: 14) {
                TripTitle(trip: trip)
                CategoryPage(summary: summary, source: .trip(trip.uuid), interval: DateInterval(start: .distantPast, end: .distantFuture))
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .paperBackground()
    }
}

private struct TotalsCard: View {
    let summary: PeriodSummary
    @Environment(\.currencyCode) private var code

    var body: some View {
        VStack(spacing: 8) {
            total("Income", summary.income.money(code), color: Palette.income, size: 17)
            total("Spent", summary.expense.money(code), color: Palette.ink, size: 17)
            Divider().overlay(Palette.pencil.opacity(0.4))
            total("Balance", summary.balance.signedMoney(code), color: summary.balance < 0 ? Palette.expense : Palette.income, size: 22)
        }
        .sketchyCard(seed: 31, padding: 14)
        .animation(.snappy, value: summary.balance)
    }

    private func total(_ title: LocalizedStringKey, _ value: String, color: Color, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.crayon(15, relativeTo: .subheadline, bold: false))
                .foregroundStyle(Palette.pencil)
            Spacer(minLength: 0)
            Text(value)
                .font(.crayon(size, relativeTo: .headline))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PageDots: View {
    @Binding var page: ReportPage?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReportPage.allCases) { item in
                let isSelected = item == page
                Button {
                    withAnimation(.snappy) { page = item }
                } label: {
                    Circle()
                        .fill(isSelected ? Palette.ink : Palette.pencil.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .padding(6)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: page)
    }
}

private struct CategoryPage: View {
    let summary: PeriodSummary
    let source: EntrySource
    let interval: DateInterval
    @State private var openSlice: CategorySlice?
    @Environment(\.currencyCode) private var code

    var body: some View {
        if summary.slices.isEmpty {
            MerEmptyState(title: "No spending", message: "Mer found no expenses in this period.")
                .padding(.top, 24)
        } else {
            VStack(spacing: 18) {
                donut
                legend
            }
            .sheet(item: $openSlice) { slice in
                EntriesSheet(title: slice.name, source: source, interval: interval, expensesIn: slice.id)
            }
        }
    }

    private var donut: some View {
        Chart(summary.slices) { slice in
            SectorMark(angle: .value("Spent", slice.total.double), innerRadius: .ratio(0.6), angularInset: 1.5)
                .cornerRadius(4)
                .foregroundStyle(slice.crayon.color)
        }
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text("Spent")
                    .font(.crayon(13, relativeTo: .caption, bold: false))
                    .foregroundStyle(Palette.pencil)
                Text(verbatim: summary.approximatePrefix + summary.expense.money(code))
                    .font(.crayon(20, relativeTo: .title3))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: 120)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .id(interval)
        .sketchyCard(seed: 32)
    }

    private var legend: some View {
        VStack(spacing: 10) {
            ForEach(summary.slices) { slice in
                Button {
                    openSlice = slice
                } label: {
                    HStack(spacing: 12) {
                        CategoryBadge(symbol: slice.symbol, crayon: slice.crayon, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slice.name)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(share(of: slice), format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(Palette.pencil)
                        }
                        Spacer(minLength: 8)
                        Text(slice.total.money(code))
                            .font(.crayon(17, relativeTo: .body))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.pencil)
                    }
                    .foregroundStyle(Palette.ink)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
        .sketchyCard(seed: 33)
    }

    private func share(of slice: CategorySlice) -> Double {
        summary.expense > 0 ? (slice.total / summary.expense).double : 0
    }
}

#Preview {
    ReportView()
        .modelContainer(Store.preview)
}
