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
    /// The amount taken from or added to the account, in the account's currency.
    var amount: Decimal = 0
    var accountCode: String = ""
    /// Set only when the entry was typed in another currency and converted into the account's currency.
    var originalAmount: Decimal?
    var originalCode: String?
    var kindRaw: String = EntryKind.expense.rawValue
    var note: String = ""
    var date: Date = Date.now
    var category: EntryCategory?

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
    /// Set only on built-in categories. Two devices that seed the same category produce the same key, so the copies can merge.
    var seedKey: String?
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
