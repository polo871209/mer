import Foundation
import SwiftData

enum Store {
    static let shared: ModelContainer = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sampleData") { return preview }
        #endif
        return make(inMemory: false)
    }()

    static func make(inMemory: Bool) -> ModelContainer {
        let schema = Schema([Entry.self, EntryCategory.self, Trip.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: inMemory ? .none : .automatic)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            seedCategories(in: container.mainContext)
            return container
        } catch {
            fatalError("Could not open the Mer store: \(error)")
        }
    }

    static func mergeDuplicateCategories(in context: ModelContext) {
        let seeded = FetchDescriptor<EntryCategory>(predicate: #Predicate { $0.seedKey != nil })
        guard let categories = try? context.fetch(seeded) else { return }
        let duplicateGroups = Dictionary(grouping: categories) { $0.seedKey }.values.filter { $0.count > 1 }
        guard !duplicateGroups.isEmpty else { return }
        for group in duplicateGroups {
            let sorted = group.sorted { $0.uuid.uuidString < $1.uuid.uuidString }
            for duplicate in sorted.dropFirst() {
                for entry in duplicate.entries ?? [] { entry.category = sorted[0] }
                context.delete(duplicate)
            }
        }
        try? context.save()
    }

    private struct CategorySeed {
        let key: String
        let name: String
        let symbol: String
        let crayon: Crayon
        let kind: EntryKind
        var isInBudget = true
    }

    private static let categorySeeds = [
        CategorySeed(key: "food", name: String(localized: "Food"), symbol: "fork.knife", crayon: .blush, kind: .expense),
        CategorySeed(key: "groceries", name: String(localized: "Groceries"), symbol: "cart", crayon: .butter, kind: .expense),
        CategorySeed(key: "transport", name: String(localized: "Transport"), symbol: "tram", crayon: .sky, kind: .expense),
        CategorySeed(key: "shopping", name: String(localized: "Shopping"), symbol: "bag", crayon: .lilac, kind: .expense),
        CategorySeed(key: "bills", name: String(localized: "Bills"), symbol: "bolt", crayon: .tangerine, kind: .expense),
        CategorySeed(key: "rent", name: String(localized: "Rent"), symbol: "house", crayon: .fur, kind: .expense, isInBudget: false),
        CategorySeed(key: "school", name: String(localized: "School"), symbol: "graduationcap", crayon: .sage, kind: .expense, isInBudget: false),
        CategorySeed(key: "fun", name: String(localized: "Fun"), symbol: "gamecontroller", crayon: .sky, kind: .expense),
        CategorySeed(key: "health", name: String(localized: "Health"), symbol: "cross.case", crayon: .sage, kind: .expense),
        CategorySeed(key: "sport", name: String(localized: "Sport"), symbol: "dumbbell", crayon: .tangerine, kind: .expense),
        CategorySeed(key: "travel", name: String(localized: "Travel"), symbol: "airplane", crayon: .lilac, kind: .expense),
        CategorySeed(key: "gift", name: String(localized: "Gift"), symbol: "gift", crayon: .blush, kind: .expense),
        CategorySeed(key: "pets", name: String(localized: "Pets"), symbol: "pawprint", crayon: .fur, kind: .expense),
        CategorySeed(key: "other", name: String(localized: "Other"), symbol: "ellipsis", crayon: .cocoa, kind: .expense),
        CategorySeed(key: "salary", name: String(localized: "Salary"), symbol: "banknote", crayon: .sage, kind: .income),
        CategorySeed(key: "side-gig", name: String(localized: "Side Gig"), symbol: "briefcase", crayon: .sky, kind: .income),
        CategorySeed(key: "investment", name: String(localized: "Investment"), symbol: "chart.line.uptrend.xyaxis", crayon: .lilac, kind: .income),
        CategorySeed(key: "gift-income", name: String(localized: "Gift"), symbol: "gift", crayon: .blush, kind: .income),
        CategorySeed(key: "other-income", name: String(localized: "Other Income"), symbol: "sparkles", crayon: .butter, kind: .income),
    ]

    private static func seedCategories(in context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<EntryCategory>())) == 0 else { return }
        for (index, seed) in categorySeeds.enumerated() {
            let category = EntryCategory(name: seed.name, symbol: seed.symbol, crayon: seed.crayon, kind: seed.kind, sortOrder: index, seedKey: seed.key)
            category.isInBudget = seed.isInBudget
            context.insert(category)
        }
        try? context.save()
    }
}

// Not behind `#if DEBUG`, because `#Preview` blocks also compile in Release.
extension Store {
    static let preview: ModelContainer = {
        let container = make(inMemory: true)
        let context = container.mainContext
        let categories = (try? context.fetch(FetchDescriptor<EntryCategory>())) ?? []
        func seeded(_ key: String) -> EntryCategory? { categories.first { $0.seedKey == key } }
        let calendar = Calendar.current
        @discardableResult
        func add(_ amount: Decimal, _ kind: EntryKind, _ category: EntryCategory?, daysAgo: Int, note: String = "") -> Entry {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let entry = Entry(amount: amount, accountCode: Money.mainCode, kind: kind, date: date, note: note)
            context.insert(entry)
            entry.category = category
            return entry
        }
        add(4200, .income, seeded("salary"), daysAgo: 12)
        add(12.5, .expense, seeded("food"), daysAgo: 0, note: "Nasi lemak")
        add(86.2, .expense, seeded("groceries"), daysAgo: 2)
        add(4.2, .expense, seeded("transport"), daysAgo: 4, note: "Train")
        add(129, .expense, seeded("shopping"), daysAgo: 6, note: "Shoes")
        add(210, .expense, seeded("bills"), daysAgo: 8, note: "Electricity")
        add(1200, .expense, seeded("rent"), daysAgo: 9)
        add(38, .expense, seeded("pets"), daysAgo: 10, note: "Cat food")
        add(22, .expense, seeded("fun"), daysAgo: 12, note: "Cinema")
        add(15.8, .expense, seeded("food"), daysAgo: 14, note: "Coffee")
        let ramen = add(41.2, .expense, seeded("food"), daysAgo: 3, note: "Ramen")
        ramen.originalAmount = 1600
        ramen.originalCode = "JPY"
        let trip = Trip(name: "Tokyo", start: calendar.date(byAdding: .day, value: -3, to: .now))
        trip.currencyCode = "JPY"
        context.insert(trip)
        ramen.trip = trip
        add(612, .expense, seeded("travel"), daysAgo: 40, note: "Flight").trip = trip
        return container
    }()
}
