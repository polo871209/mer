import Foundation
import SwiftData

nonisolated enum EntryKind: String, CaseIterable, Identifiable {
    case expense, income

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .expense: "Expense"
        case .income: "Income"
        }
    }
}

@Model
final class Entry {
    #Index<Entry>([\.accountCode, \.date], [\.date])

    var amount: Decimal = 0
    var accountCode: String = ""
    var originalAmount: Decimal?
    var originalCode: String?
    var mainAmount: Decimal?
    var mainCode: String?
    var kindRaw: String = EntryKind.expense.rawValue
    var note: String = ""
    var date: Date = Date.now
    var category: EntryCategory?
    var trip: Trip?

    init(amount: Decimal, accountCode: String, kind: EntryKind, date: Date = .now, note: String = "") {
        self.amount = amount
        self.accountCode = accountCode
        self.kindRaw = kind.rawValue
        self.date = date
        self.note = note
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var signedAmount: Decimal { kind == .income ? amount : -amount }

    var countsInBudget: Bool { trip == nil && category?.isInBudget ?? true }

    var typedAmount: Decimal { originalAmount ?? amount }
    var typedCode: String { originalCode ?? accountCode }

    var title: String {
        note.isEmpty ? category.displayName : note
    }
}

@Model
final class EntryCategory {
    /// Stable ID for App Intents, which cannot use `PersistentIdentifier`.
    var uuid: UUID = UUID()
    var name: String = ""
    var symbol: String = "tag"
    var crayonRaw: String = Crayon.butter.rawValue
    var kindRaw: String = EntryKind.expense.rawValue
    var sortOrder: Int = 0
    var seedKey: String?
    var isInBudget: Bool = true
    @Relationship(deleteRule: .nullify, inverse: \Entry.category)
    var entries: [Entry]? = []

    init(name: String, symbol: String, crayon: Crayon, kind: EntryKind, sortOrder: Int, seedKey: String? = nil) {
        self.name = name
        self.symbol = symbol
        self.crayonRaw = crayon.rawValue
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.seedKey = seedKey
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var crayon: Crayon {
        get { Crayon(rawValue: crayonRaw) ?? .butter }
        set { crayonRaw = newValue.rawValue }
    }
}

nonisolated extension EntryCategory? {
    var displayName: String { self?.name ?? String(localized: "Uncategorized") }
    var displaySymbol: String { self?.symbol ?? "questionmark" }
    var displayCrayon: Crayon { self?.crayon ?? .cocoa }
}
