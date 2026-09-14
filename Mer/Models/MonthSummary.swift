import Foundation

struct CategorySlice: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let crayon: Crayon
    let total: Decimal
}

struct DayTotal: Identifiable {
    let day: Date
    let expense: Decimal
    var id: Date { day }
}

struct MonthSummary {
    let income: Decimal
    let expense: Decimal
    let slices: [CategorySlice]
    let days: [DayTotal]
    let isEmpty: Bool

    var balance: Decimal { income - expense }

    init(entries: [Entry], calendar: Calendar = .current) {
        var income = Decimal.zero
        var expense = Decimal.zero
        var byCategory: [String: CategorySlice] = [:]
        var byDay: [Date: Decimal] = [:]
        for entry in entries {
            switch entry.kind {
            case .income:
                income += entry.amount
            case .expense:
                expense += entry.amount
                let key = entry.category?.uuid.uuidString ?? "none"
                byCategory[key] = CategorySlice(
                    id: key,
                    name: entry.category?.name ?? String(localized: "Uncategorized"),
                    symbol: entry.category?.symbol ?? "questionmark",
                    crayon: entry.category?.crayon ?? .cocoa,
                    total: (byCategory[key]?.total ?? 0) + entry.amount
                )
                byDay[calendar.startOfDay(for: entry.date), default: 0] += entry.amount
            }
        }
        self.income = income
        self.expense = expense
        self.slices = byCategory.values.sorted { $0.total > $1.total }
        self.days = byDay.map { DayTotal(day: $0.key, expense: $0.value) }.sorted { $0.day < $1.day }
        self.isEmpty = entries.isEmpty
    }
}

nonisolated enum MerMood: Equatable {
    case waiting, happy, treats

    init(summary: MonthSummary) {
        if summary.isEmpty {
            self = .waiting
        } else {
            self = summary.income >= summary.expense ? .happy : .treats
        }
    }

    var line: LocalizedStringResource {
        switch self {
        case .waiting: "Nothing logged yet. Mer is waiting in the bowl."
        case .happy: "Looking good. Mer approves."
        case .treats: "More out than in. Mer says treats cost money too."
        }
    }
}

extension Calendar {
    func monthInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}
