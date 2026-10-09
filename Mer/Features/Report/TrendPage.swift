import Charts
import SwiftData
import SwiftUI

struct TrendPage: View {
    let period: Period
    let interval: DateInterval
    let spent: Decimal
    private let range: DateInterval
    @Query private var entries: [Entry]
    @Environment(\.currencyCode) private var code

    private static let incomeLabel = String(localized: "Income")
    private static let spentLabel = String(localized: "Spent")

    init(account: String, period: Period, interval: DateInterval, spent: Decimal) {
        let range = TrendBucket.range(for: period, containing: interval.start)
        let end = range.end
        self.period = period
        self.interval = interval
        self.spent = spent
        self.range = range
        _entries = Query(filter: #Predicate<Entry> { $0.accountCode == account && $0.date < end })
    }

    var body: some View {
        if entries.isEmpty {
            MerEmptyState(title: "No entries", message: "Log some money in or out to see the trend.")
                .padding(.top, 24)
        } else {
            VStack(spacing: 18) {
                chart
                average
            }
        }
    }

    private var chart: some View {
        let buckets = TrendBucket.buckets(for: entries, period: period, range: range)
        return VStack(alignment: .leading, spacing: 14) {
            Text(period.trendTitle).cardTitle()
            legend
            Chart(buckets) { bucket in
                BarMark(x: .value("Period", bucket.label), y: .value("Amount", bucket.income.double))
                    .foregroundStyle(by: .value("Type", Self.incomeLabel))
                    .position(by: .value("Type", Self.incomeLabel))
                    .cornerRadius(3)
                BarMark(x: .value("Period", bucket.label), y: .value("Amount", bucket.expense.double))
                    .foregroundStyle(by: .value("Type", Self.spentLabel))
                    .position(by: .value("Type", Self.spentLabel))
                    .cornerRadius(3)
            }
            .chartYScale(domain: .automatic(dataType: Double.self) { domain in domain += buckets.map { max($0.balance, 0).double } })
            .chartForegroundStyleScale(domain: [Self.incomeLabel, Self.spentLabel], range: [Palette.income, Palette.expense])
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(anchor: .top)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel(anchor: .leading)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let plotFrame = proxy.plotFrame {
                        let origin = geometry[plotFrame].origin
                        BalanceLine(
                            points: buckets.compactMap { bucket in
                                guard let x = proxy.position(forX: bucket.label),
                                    let y = proxy.position(forY: max(bucket.balance, 0).double)
                                else { return nil }
                                return BalancePoint(
                                    id: bucket.id,
                                    position: CGPoint(x: origin.x + x, y: origin.y + y),
                                    isBelowZero: bucket.balance < 0
                                )
                            }
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(height: 240)
            .id(range)
        }
        .foregroundStyle(Palette.ink)
        .sketchyCard(seed: 34)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Circle().fill(Palette.income).frame(width: 8, height: 8)
                Text(Self.incomeLabel)
            }
            HStack(spacing: 5) {
                Circle().fill(Palette.expense).frame(width: 8, height: 8)
                Text(Self.spentLabel)
            }
            HStack(spacing: 5) {
                SketchyCurve(points: [CGPoint(x: 1, y: 7), CGPoint(x: 9, y: 2), CGPoint(x: 17, y: 4)])
                    .stroke(Palette.balance, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 18, height: 8)
                Text("Balance")
            }
        }
        .font(.caption)
        .foregroundStyle(Palette.pencil)
        .accessibilityHidden(true)
    }

    private var average: some View {
        HStack {
            Text(period.averageTitle)
                .foregroundStyle(Palette.pencil)
            Spacer(minLength: 8)
            Text(averageSpent.money(code))
                .font(.crayon(17, relativeTo: .body))
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
        .sketchyCard(seed: 35, padding: 14)
    }

    private var averageSpent: Decimal {
        let calendar = Calendar.current
        let unit = period.averageUnit
        let end = min(interval.end, .now)
        guard end > interval.start else { return 0 }
        let whole = calendar.dateComponents([unit], from: interval.start, to: end).value(for: unit) ?? 0
        let count = whole + (end < interval.end ? 1 : 0)
        return (spent / Decimal(max(count, 1))).rounded(scale: Money.fractionDigits)
    }
}

private struct BalancePoint: Identifiable {
    let id: Int
    let position: CGPoint
    let isBelowZero: Bool
}

private struct BalanceLine: View {
    let points: [BalancePoint]

    var body: some View {
        let positions = points.map(\.position)
        ZStack {
            SketchyCurve(points: positions, wobble: 1.2, seed: 52)
                .stroke(Palette.balance.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            SketchyCurve(points: positions)
                .stroke(Palette.balance, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            ForEach(points) { point in
                ZStack {
                    Circle().fill(Palette.card).frame(width: 13, height: 13)
                    SketchyEllipse(seed: UInt64(point.id) &+ 60)
                        .fill(point.isBelowZero ? Palette.expense : Palette.balance)
                        .frame(width: 8, height: 8)
                }
                .position(point.position)
            }
        }
    }
}

private struct TrendBucket: Identifiable {
    let id: Int
    let label: String
    var income = Decimal.zero
    var expense = Decimal.zero
    var balance = Decimal.zero

    static func range(for period: Period, containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let current = period.interval(containing: date, calendar: calendar)
        let start = calendar.date(byAdding: period.unit, value: 1 - period.trendCount, to: current.start) ?? current.start
        return DateInterval(start: start, end: current.end)
    }

    static func buckets(
        for entries: [Entry],
        period: Period,
        range: DateInterval,
        calendar: Calendar = .current
    ) -> [TrendBucket] {
        var buckets = (0..<period.trendCount).map { offset in
            let date = calendar.date(byAdding: period.unit, value: offset, to: range.start) ?? range.start
            return TrendBucket(id: offset, label: period.bucketLabel(for: date))
        }
        let index = { (date: Date) in
            calendar.dateComponents([period.unit], from: range.start, to: date).value(for: period.unit) ?? -1
        }
        var opening = Decimal.zero
        for entry in entries {
            guard entry.date >= range.start else {
                opening += entry.signedAmount
                continue
            }
            let position = index(entry.date)
            guard buckets.indices.contains(position) else { continue }
            switch entry.kind {
            case .income: buckets[position].income += entry.amount
            case .expense: buckets[position].expense += entry.amount
            }
        }
        var running = opening
        for position in buckets.indices {
            running += buckets[position].income - buckets[position].expense
            buckets[position].balance = running
        }
        return buckets
    }
}

extension Period {
    fileprivate var trendTitle: LocalizedStringKey {
        switch self {
        case .month: "Month by month"
        case .year: "Year by year"
        }
    }

    fileprivate var averageTitle: LocalizedStringKey {
        switch self {
        case .month: "Average spent per day"
        case .year: "Average spent per month"
        }
    }

    fileprivate var averageUnit: Calendar.Component {
        switch self {
        case .month: .day
        case .year: .month
        }
    }

    fileprivate var trendCount: Int {
        switch self {
        case .month: 6
        case .year: 5
        }
    }

    fileprivate func bucketLabel(for date: Date) -> String {
        switch self {
        case .month: date.formatted(.dateTime.month(.abbreviated))
        case .year: date.formatted(.dateTime.year())
        }
    }
}
