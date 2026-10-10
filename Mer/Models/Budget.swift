import Foundation

nonisolated enum BudgetLevel {
    case under, near, reached
}

nonisolated enum MonthlyBudget {
    static func limit(isOn: Bool, stored: Double) -> Decimal? {
        guard isOn, stored > 0 else { return nil }
        return Decimal(stored).rounded(scale: Money.fractionDigits)
    }
}

nonisolated struct BudgetProgress {
    let limit: Decimal
    let spent: Decimal

    var left: Decimal { limit - spent }
    var isOver: Bool { spent > limit }
    var share: Double { (spent / limit).double }
    var limitShare: Double? { isOver ? (limit / spent).double : nil }

    var level: BudgetLevel {
        if spent >= limit { return .reached }
        return share >= 0.8 ? .near : .under
    }
}
