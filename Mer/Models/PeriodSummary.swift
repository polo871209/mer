import Foundation

nonisolated struct CategorySlice: Identifiable {
    let id: UUID?
    let name: String
    let symbol: String
    let crayon: Crayon
    let total: Decimal
}

nonisolated struct DayTotal: Identifiable {
    let day: Date
    let expense: Decimal
    var id: Date { day }
}

struct PeriodSummary {
    let income: Decimal
    let expense: Decimal
    let slices: [CategorySlice]
    let days: [DayTotal]
    let isEmpty: Bool

    var balance: Decimal { income - expense }

    init(entries: [Entry], calendar: Calendar = .current) {
        var income = Decimal.zero
        var expense = Decimal.zero
        var byCategory: [UUID?: (category: EntryCategory?, total: Decimal)] = [:]
        var byDay: [Date: Decimal] = [:]
        for entry in entries {
            switch entry.kind {
            case .income:
                income += entry.amount
            case .expense:
                expense += entry.amount
                let category = entry.category
                byCategory[category?.uuid, default: (category, 0)].total += entry.amount
                byDay[calendar.startOfDay(for: entry.date), default: 0] += entry.amount
            }
        }
        self.income = income
        self.expense = expense
        self.slices =
            byCategory
            .map { id, value in
                CategorySlice(
                    id: id,
                    name: value.category.displayName,
                    symbol: value.category.displaySymbol,
                    crayon: value.category.displayCrayon,
                    total: value.total
                )
            }
            .sorted { $0.total > $1.total }
        self.days = byDay.map { DayTotal(day: $0.key, expense: $0.value) }.sorted { $0.day < $1.day }
        self.isEmpty = entries.isEmpty
    }
}

nonisolated enum MerMood {
    case waiting, happy, treats

    init(summary: PeriodSummary) {
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
