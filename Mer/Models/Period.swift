import Foundation

nonisolated enum Period: String, CaseIterable, Identifiable {
    case month, year

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .month: "Month"
        case .year: "Year"
        }
    }

    var unit: Calendar.Component {
        switch self {
        case .month: .month
        case .year: .year
        }
    }

    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: unit, for: date) ?? DateInterval(start: date, duration: 0)
    }

    func label(for date: Date) -> String {
        switch self {
        case .month: date.formatted(.dateTime.month(.wide).year())
        case .year: date.formatted(.dateTime.year())
        }
    }
}
