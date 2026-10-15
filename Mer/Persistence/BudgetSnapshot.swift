import Foundation

nonisolated struct BudgetSnapshot: Codable, Hashable, Sendable {
    let month: Date
    let spent: Decimal
    let limit: Decimal?

    static var stored: BudgetSnapshot? {
        guard let data = UserDefaults.appGroup?.data(forKey: DefaultsKey.widgetBudget) else { return nil }
        return try? JSONDecoder().decode(BudgetSnapshot.self, from: data)
    }

    func save() {
        UserDefaults.appGroup?.set(try? JSONEncoder().encode(self), forKey: DefaultsKey.widgetBudget)
    }

    func spent(on date: Date) -> Decimal {
        Period.month.interval(containing: date).contains(month) ? spent : 0
    }
}
