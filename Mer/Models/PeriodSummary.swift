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
    let isApproximate: Bool

    var balance: Decimal { income - expense }
    var approximatePrefix: String { isApproximate ? "≈ " : "" }

    init(entries: [Entry], convertingTo mainCode: String? = nil, calendar: Calendar = .current) {
        var income = Decimal.zero
        var expense = Decimal.zero
        var isApproximate = false
        var byCategory: [UUID?: (category: EntryCategory?, total: Decimal)] = [:]
        var byDay: [Date: Decimal] = [:]
        for entry in entries {
            let converted = mainCode.map { entry.amount(in: $0) } ?? (value: entry.amount, isApproximate: false)
            let amount = converted.value
            if converted.isApproximate { isApproximate = true }
            switch entry.kind {
            case .income:
                income += amount
            case .expense:
                expense += amount
                let category = entry.category
                byCategory[category?.uuid, default: (category, 0)].total += amount
                byDay[calendar.startOfDay(for: entry.date), default: 0] += amount
            }
        }
        self.isApproximate = isApproximate
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
    case waiting, happy, treats, travelling, nearBudget, budgetReached

    init(summary: PeriodSummary) {
        if summary.isEmpty {
            self = .waiting
        } else {
            self = summary.income >= summary.expense ? .happy : .treats
        }
    }

    init(budget: BudgetProgress) {
        switch budget.level {
        case .under: self = .happy
        case .near: self = .nearBudget
        case .reached: self = .budgetReached
        }
    }

    var line: LocalizedStringResource {
        switch self {
        case .waiting: "Nothing logged yet. Mer is waiting in the bowl."
        case .happy: "Looking good. Mer approves."
        case .treats: "More out than in. Mer says treats cost money too."
        case .travelling: "Mer is on a trip. Spending here stays out of the budget."
        case .nearBudget: "Almost at the budget. Mer is watching."
        case .budgetReached: "The budget is used up. Mer is hiding the treats."
        }
    }
}
