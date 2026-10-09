import AppIntents
import Foundation
import SwiftData

// The entity and query are nonisolated because App Intents calls them off the main actor.
// Their methods hop to the main actor to use `Store.shared.mainContext`.

nonisolated struct CategoryEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let defaultQuery = CategoryQuery()

    let id: UUID
    let name: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }
}

nonisolated struct CategoryQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        try expenseCategories(#Predicate { identifiers.contains($0.uuid) })
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        try expenseCategories(.true)
    }

    @MainActor
    private func expenseCategories(_ filter: Predicate<EntryCategory>) throws -> [CategoryEntity] {
        let expense = EntryKind.expense.rawValue
        let descriptor = FetchDescriptor<EntryCategory>(
            predicate: #Predicate { $0.kindRaw == expense && filter.evaluate($0) },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try Store.shared.mainContext.fetch(descriptor).map { CategoryEntity(id: $0.uuid, name: $0.name, symbol: $0.symbol) }
    }
}

struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Expense"
    static let description = IntentDescription("Writes an expense into Mer without opening the app.")

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category")
    var category: CategoryEntity?

    @Parameter(title: "Note", default: "")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$category)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw $amount.needsValueError("How much did you spend?")
        }
        let context = Store.shared.mainContext
        let code = Money.mainCode
        let value = Decimal(amount).rounded(scale: Money.fractionDigits(code))
        var match: EntryCategory?
        if let id = category?.id {
            match = try context.fetch(FetchDescriptor<EntryCategory>(predicate: #Predicate { $0.uuid == id })).first
        }
        let entry = Entry(amount: value, accountCode: code, kind: .expense, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(entry)
        entry.category = match
        try context.save()
        return .result(dialog: "Logged \(value.money(code)). Mer wrote it down.")
    }
}

struct MonthSpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Spent This Month"
    static let description = IntentDescription("Tells you how much you spent this month.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let interval = Period.month.interval(containing: .now)
        let start = interval.start
        let end = interval.end
        let expense = EntryKind.expense.rawValue
        let main = Money.mainCode
        let entries = try Store.shared.mainContext.fetch(
            FetchDescriptor<Entry>(predicate: #Predicate { $0.accountCode == main && $0.date >= start && $0.date < end && $0.kindRaw == expense })
        )
        let spent = entries.reduce(Decimal.zero) { $0 + $1.amount }.money(main)
        return .result(dialog: "You spent \(spent) this month.")
    }
}

nonisolated struct MerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "pencil.and.scribble"
        )
        AppShortcut(
            intent: MonthSpendingIntent(),
            phrases: [
                "How much did I spend in \(.applicationName)",
                "Check my spending in \(.applicationName)",
            ],
            shortTitle: "Spent This Month",
            systemImageName: "chart.pie"
        )
    }
}
