import AppIntents
import SwiftData
import SwiftUI

// The entities and queries are nonisolated because App Intents calls them off the main actor.

nonisolated struct CategoryEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let defaultQuery = CategoryQuery()

    let id: UUID
    let name: String
    let symbol: String
    let kind: EntryKind

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: kind.title, image: .init(systemName: symbol))
    }
}

nonisolated struct CategoryQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        try categories(#Predicate { identifiers.contains($0.uuid) })
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        try categories(.true)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        guard let query = SearchQuery(string) else { return [] }
        return try categories(.true).filter { query.matches([$0.name]) }
    }

    @MainActor
    private func categories(_ filter: Predicate<EntryCategory>) throws -> [CategoryEntity] {
        let descriptor = FetchDescriptor(predicate: filter, sortBy: [SortDescriptor(\.sortOrder)])
        let categories = try Store.shared.mainContext.fetch(descriptor)
        let expensesFirst = categories.filter { $0.kind == .expense } + categories.filter { $0.kind == .income }
        return expensesFirst.map { CategoryEntity(id: $0.uuid, name: $0.name, symbol: $0.symbol, kind: $0.kind) }
    }
}

nonisolated struct CurrencyEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Currency"
    static let defaultQuery = CurrencyQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(Money.name(id))", subtitle: "\(id)")
    }
}

nonisolated struct CurrencyQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CurrencyEntity] {
        identifiers.map(CurrencyEntity.init)
    }

    func suggestedEntities() async throws -> [CurrencyEntity] {
        Accounts.stored.all.map(CurrencyEntity.init)
    }

    func entities(matching string: String) async throws -> [CurrencyEntity] {
        guard let query = SearchQuery(string) else { return [] }
        return Locale.commonISOCurrencyCodes.filter { query.matches([$0, Money.name($0)]) }.map(CurrencyEntity.init)
    }
}

nonisolated enum AddEntryError: Error, CustomLocalizedStringResourceConvertible {
    case noExchangeRate(from: String, to: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noExchangeRate(let currency, let account):
            "Mer has no exchange rate from \(currency) to \(account) yet. Connect to the internet and try again."
        }
    }
}

struct AddEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Entry"
    static let description = IntentDescription("Writes an expense or income into Mer without opening the app.")

    @Parameter(title: "Amount", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "Category", requestValueDialog: "Which category?")
    var category: CategoryEntity

    @Parameter(title: "Currency")
    var currency: CurrencyEntity?

    @Parameter(title: "Date")
    var date: Date?

    @Parameter(title: "Note", default: "")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) to \(\.$category)") {
            \.$currency
            \.$date
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let typed = Decimal(amount).rounded(scale: Money.fractionDigits)
        guard typed > 0 else {
            throw $amount.needsValueError("How much?")
        }
        let context = Store.shared.mainContext
        let date = date ?? .now
        let trip = try context.fetch(FetchDescriptor<Trip>()).current(at: date)
        let accounts = Accounts.stored
        let currency = currency?.id ?? trip?.currencyCode ?? accounts.main
        let account = accounts.account(for: currency)
        if currency != accounts.main {
            await ExchangeRates.shared.refreshIfStale()
        }
        var accountAmount = typed
        if account != currency {
            let conversion = Conversion(account: account, rate: ExchangeRates.shared.rate(from: currency, to: account))
            guard let converted = conversion.convert(typed) else {
                throw AddEntryError.noExchangeRate(from: currency, to: account)
            }
            accountAmount = converted
        }
        let categoryID = category.id
        let match = try context.fetch(FetchDescriptor<EntryCategory>(predicate: #Predicate { $0.uuid == categoryID })).first
        let kind = match?.kind ?? category.kind
        let entry = Entry(amount: accountAmount, accountCode: account, kind: kind, date: date, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(entry)
        entry.setAmount(typed, currency: currency, accountAmount: accountAmount, account: account, trip: trip)
        entry.category = match
        try context.save()
        BudgetSnapshot.refresh(in: context)
        return .result(dialog: dialog(for: entry, typed: typed.money(currency)), view: EntryRow(entry: entry).padding())
    }

    private func dialog(for entry: Entry, typed money: String) -> IntentDialog {
        let name = entry.category.displayName
        let full: LocalizedStringResource =
            switch (entry.kind, entry.trip?.name) {
            case (.expense, let trip?): "Logged \(money) for \(name) on \(trip)."
            case (.expense, nil): "Logged \(money) for \(name)."
            case (.income, let trip?): "Logged \(money) from \(name) on \(trip)."
            case (.income, nil): "Logged \(money) from \(name)."
            }
        return IntentDialog(full: full, supporting: "Mer wrote it down.")
    }
}

struct MonthSpendingIntent: AppIntent {
    static let title: LocalizedStringResource = "Spent This Month"
    static let description = IntentDescription("Tells you how much you spent this month.")
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let interval = Period.month.interval(containing: .now)
        let start = interval.start
        let end = interval.end
        let expense = EntryKind.expense.rawValue
        let main = Money.mainCode
        let entries = try Store.shared.mainContext.fetch(
            FetchDescriptor<Entry>(
                predicate: #Predicate { $0.accountCode == main && $0.date >= start && $0.date < end && $0.kindRaw == expense && $0.trip == nil })
        )
        let spent = entries.reduce(Decimal.zero) { $0 + $1.amount }.money(main)
        return .result(dialog: "You spent \(spent) this month.")
    }
}

nonisolated struct MerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddEntryIntent(),
            phrases: [
                "Log \(\.$category) in \(.applicationName)",
                "Add \(\.$category) to \(.applicationName)",
                "Add \(\.$category) in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
                "Add an entry to \(.applicationName)",
            ],
            shortTitle: "Add Entry",
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
