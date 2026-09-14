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
    var amount: Decimal = 0
    var kindRaw: String = EntryKind.expense.rawValue
    var note: String = ""
    var date: Date = Date.now
    var category: EntryCategory?

    init(amount: Decimal, kind: EntryKind, date: Date = .now, note: String = "") {
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.date = date
        self.note = note
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var signedAmount: Decimal { kind == .income ? amount : -amount }

    var title: String {
        note.isEmpty ? (category?.name ?? String(localized: "Uncategorized")) : note
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
