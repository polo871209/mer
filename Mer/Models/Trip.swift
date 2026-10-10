import SwiftData
import SwiftUI

@Model
final class Trip {
    var uuid: UUID = UUID()
    var name: String = ""
    var start: Date?
    var end: Date?
    var isClaimable: Bool = true
    var currencyCode: String?
    @Relationship(deleteRule: .nullify, inverse: \Entry.trip)
    var entries: [Entry]? = []

    init(name: String, start: Date? = nil, end: Date? = nil, isClaimable: Bool = true) {
        self.name = name
        self.start = start
        self.end = end
        self.isClaimable = isClaimable
    }

    func status(at now: Date = .now) -> TripStatus {
        guard let start, start <= now else { return .planned }
        if let end, end <= now { return .ended }
        return .active
    }

    var datesText: String? {
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        let lastDay = end?.addingTimeInterval(-1)
        switch (start, lastDay) {
        case (let start?, let lastDay?) where start <= lastDay:
            return (start..<lastDay).formatted(.interval.month(.abbreviated).day())
        case (let start?, _):
            return String(localized: "From \(start.formatted(format))")
        case (nil, let lastDay?):
            return String(localized: "Until \(lastDay.formatted(format))")
        case (nil, nil):
            return nil
        }
    }

    var statusText: String {
        let status = String(localized: status().title)
        return datesText.map { "\(status) · \($0)" } ?? status
    }
}

nonisolated enum TripStatus: CaseIterable {
    case active, planned, ended

    var title: LocalizedStringResource {
        switch self {
        case .active: "On Trip"
        case .planned: "Planned"
        case .ended: "Ended"
        }
    }
}

extension Sequence<Trip> {
    func current(at now: Date = .now) -> Trip? {
        filter { $0.status(at: now) == .active }.max { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }

    func boundaries(after now: Date) -> [Date] {
        flatMap { [$0.start, $0.end].compactMap(\.self) }.filter { $0 > now }.sorted()
    }
}

extension EnvironmentValues {
    @Entry var currentTripID: PersistentIdentifier?
}

extension Entry {
    @MainActor func amount(in mainCode: String) -> (value: Decimal, isApproximate: Bool) {
        if accountCode == mainCode { return (amount, false) }
        if self.mainCode == mainCode, let mainAmount { return (mainAmount, false) }
        let rate = ExchangeRates.shared.rate(from: accountCode, to: mainCode)
        return ((amount * (rate ?? 0)).rounded(scale: Money.fractionDigits), true)
    }
}
