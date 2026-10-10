import Foundation
import SwiftData

struct ImportSummary {
    var added = 0
    var duplicates = 0
    var invalidLines: [Int] = []
    var accountCodes: Set<String> = []
}

nonisolated enum ImportError: LocalizedError {
    case missingColumns([String])

    var errorDescription: String? {
        switch self {
        case .missingColumns(let names):
            String(localized: "The file has no \(names.formatted()) column. Mer reads the columns that Export CSV writes.")
        }
    }
}

enum EntriesImport {
    static func run(_ text: String, into context: ModelContext) throws -> ImportSummary {
        var rows = CSV.parse(text)
        guard !rows.isEmpty else { return ImportSummary() }
        let columns = Columns(header: rows.removeFirst())
        let missing = Columns.required.filter { columns.index[$0] == nil }
        guard missing.isEmpty else { throw ImportError.missingColumns(missing) }

        var links = try Links(context: context)
        var existing = Set(try context.fetch(FetchDescriptor<Entry>()).map(EntryKey.init))
        var summary = ImportSummary()
        for (offset, row) in rows.enumerated() {
            guard let imported = ImportedRow(row, columns: columns) else {
                summary.invalidLines.append(offset + 2)
                continue
            }
            guard existing.insert(imported.key).inserted else {
                summary.duplicates += 1
                continue
            }
            let entry = imported.makeEntry()
            context.insert(entry)
            entry.category = links.category(named: imported.categoryName, kind: imported.kind)
            entry.trip = links.trip(named: imported.tripName, covering: imported.date)
            summary.added += 1
            summary.accountCodes.insert(imported.accountCode)
        }
        try context.save()
        return summary
    }
}

private struct ImportedRow {
    let date: Date
    let kind: EntryKind
    let amount: Decimal
    let accountCode: String
    let original: (amount: Decimal, code: String)?
    let categoryName: String
    let tripName: String
    let note: String

    init?(_ row: [String], columns: Columns) {
        let field = { (name: String) in columns.value(name, in: row) }
        guard let date = try? Date(field("Date"), strategy: .iso8601),
            let kind = EntryKind(rawValue: field("Type")),
            let amount = Self.decimal(field("Amount")), amount > 0,
            !field("Account").isEmpty
        else { return nil }
        self.date = date
        self.kind = kind
        self.amount = amount
        accountCode = field("Account").uppercased()
        let originalCode = field("Original Currency").uppercased()
        original = Self.decimal(field("Original Amount")).flatMap { originalCode.isEmpty ? nil : ($0, originalCode) }
        categoryName = field("Category")
        tripName = field("Trip")
        note = field("Note")
    }

    var key: EntryKey {
        EntryKey(date: date, amount: amount, accountCode: accountCode, kind: kind, note: note)
    }

    func makeEntry() -> Entry {
        let entry = Entry(amount: amount, accountCode: accountCode, kind: kind, date: date, note: note)
        entry.originalAmount = original?.amount
        entry.originalCode = original?.code
        return entry
    }

    private static func decimal(_ text: String) -> Decimal? {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
}

private struct Links {
    let context: ModelContext
    var categories: [CategoryKey: EntryCategory]
    var nextSortOrder: Int
    var trips: [String: Trip]
    var newTripNames: Set<String> = []

    init(context: ModelContext) throws {
        self.context = context
        categories = Dictionary(
            try context.fetch(FetchDescriptor<EntryCategory>()).map { (CategoryKey($0.name, $0.kind), $0) }
        ) { first, _ in first }
        nextSortOrder = (categories.values.map(\.sortOrder).max() ?? -1) + 1
        trips = Dictionary(try context.fetch(FetchDescriptor<Trip>()).map { ($0.name, $0) }) { first, _ in first }
    }

    mutating func category(named name: String, kind: EntryKind) -> EntryCategory? {
        guard !name.isEmpty else { return nil }
        let key = CategoryKey(name, kind)
        if let category = categories[key] { return category }
        let category = EntryCategory(name: name, symbol: "tag", crayon: .butter, kind: kind, sortOrder: nextSortOrder)
        context.insert(category)
        categories[key] = category
        nextSortOrder += 1
        return category
    }

    mutating func trip(named name: String, covering date: Date) -> Trip? {
        guard !name.isEmpty else { return nil }
        if trips[name] == nil {
            let trip = Trip(name: name)
            context.insert(trip)
            trips[name] = trip
            newTripNames.insert(name)
        }
        if newTripNames.contains(name) { trips[name]?.cover(date) }
        return trips[name]
    }
}

extension Trip {
    fileprivate func cover(_ date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? date
        start = min(start ?? day, day)
        end = max(end ?? nextDay, nextDay)
    }
}

private struct Columns {
    static let required = ["Date", "Type", "Category", "Amount", "Account"]

    let index: [String: Int]

    init(header: [String]) {
        index = Dictionary(header.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) }) { first, _ in first }
    }

    func value(_ name: String, in row: [String]) -> String {
        guard let column = index[name], row.indices.contains(column) else { return "" }
        return row[column].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CategoryKey: Hashable {
    let name: String
    let kind: EntryKind

    init(_ name: String, _ kind: EntryKind) {
        self.name = name.lowercased()
        self.kind = kind
    }
}

private struct EntryKey: Hashable {
    let second: Int
    let amount: Decimal
    let accountCode: String
    let kind: EntryKind
    let note: String

    init(date: Date, amount: Decimal, accountCode: String, kind: EntryKind, note: String) {
        second = Int(date.timeIntervalSince1970.rounded(.down))
        self.amount = amount
        self.accountCode = accountCode
        self.kind = kind
        self.note = note
    }

    init(_ entry: Entry) {
        self.init(date: entry.date, amount: entry.amount, accountCode: entry.accountCode, kind: entry.kind, note: entry.note)
    }
}
