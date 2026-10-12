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
            if !inMemory { addTripCategories(in: container.mainContext) }
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
        var hiddenIn: CategoryMode?
    }

    private static let categorySeeds = [
        CategorySeed(key: "food", name: String(localized: "Food"), symbol: "fork.knife", crayon: .blush, kind: .expense),
        CategorySeed(key: "groceries", name: String(localized: "Groceries"), symbol: "cart", crayon: .butter, kind: .expense),
        CategorySeed(key: "transport", name: String(localized: "Transport"), symbol: "tram", crayon: .sky, kind: .expense),
        CategorySeed(key: "shopping", name: String(localized: "Shopping"), symbol: "bag", crayon: .lilac, kind: .expense),
        CategorySeed(key: "flight", name: String(localized: "Flight"), symbol: "airplane", crayon: .sky, kind: .expense, hiddenIn: .everyday),
        CategorySeed(key: "hotel", name: String(localized: "Hotel"), symbol: "bed.double", crayon: .lilac, kind: .expense, hiddenIn: .everyday),
        CategorySeed(key: "tours", name: String(localized: "Tours"), symbol: "ticket", crayon: .tangerine, kind: .expense, hiddenIn: .everyday),
        CategorySeed(key: "bills", name: String(localized: "Bills"), symbol: "bolt", crayon: .tangerine, kind: .expense, hiddenIn: .trip),
        CategorySeed(key: "rent", name: String(localized: "Rent"), symbol: "house", crayon: .fur, kind: .expense, isInBudget: false, hiddenIn: .trip),
        CategorySeed(
            key: "school", name: String(localized: "School"), symbol: "graduationcap", crayon: .sage, kind: .expense, isInBudget: false, hiddenIn: .trip),
        CategorySeed(key: "fun", name: String(localized: "Fun"), symbol: "gamecontroller", crayon: .sky, kind: .expense),
        CategorySeed(key: "health", name: String(localized: "Health"), symbol: "cross.case", crayon: .sage, kind: .expense, hiddenIn: .trip),
        CategorySeed(key: "beauty", name: String(localized: "Beauty"), symbol: "comb", crayon: .blush, kind: .expense, hiddenIn: .trip),
        CategorySeed(key: "sport", name: String(localized: "Sport"), symbol: "dumbbell", crayon: .tangerine, kind: .expense, hiddenIn: .trip),
        CategorySeed(key: "travel", name: String(localized: "Travel"), symbol: "suitcase", crayon: .lilac, kind: .expense, hiddenIn: .trip),
        CategorySeed(key: "gift", name: String(localized: "Gift"), symbol: "gift", crayon: .blush, kind: .expense),
        CategorySeed(key: "pets", name: String(localized: "Pets"), symbol: "pawprint", crayon: .fur, kind: .expense, hiddenIn: .trip),
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
            insert(seed, sortOrder: index, in: context)
        }
        try? context.save()
    }

    private static func addTripCategories(in context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: DefaultsKey.tripCategoriesAdded),
            let categories = try? context.fetch(FetchDescriptor<EntryCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        else { return }
        let seeded = Dictionary(categories.compactMap { category in category.seedKey.map { ($0, category) } }) { first, _ in first }
        let missing = categorySeeds.filter { $0.hiddenIn == .everyday && seeded[$0.key] == nil }
        let anchor = seeded["shopping"]?.sortOrder ?? categories.last?.sortOrder ?? -1
        for category in categories where category.sortOrder > anchor {
            category.sortOrder += missing.count
        }
        for (offset, seed) in missing.enumerated() {
            insert(seed, sortOrder: anchor + 1 + offset, in: context)
        }
        for seed in categorySeeds {
            guard let mode = seed.hiddenIn, let category = seeded[seed.key] else { continue }
            category.setHidden(true, in: mode)
        }
        if let travel = seeded["travel"], travel.symbol == "airplane" {
            travel.symbol = "suitcase"
        }
        do {
            try context.save()
            defaults.set(true, forKey: DefaultsKey.tripCategoriesAdded)
        } catch {
            context.rollback()
        }
    }

    private static func insert(_ seed: CategorySeed, sortOrder: Int, in context: ModelContext) {
        let category = EntryCategory(name: seed.name, symbol: seed.symbol, crayon: seed.crayon, kind: seed.kind, sortOrder: sortOrder, seedKey: seed.key)
        category.isInBudget = seed.isInBudget
        if let mode = seed.hiddenIn { category.setHidden(true, in: mode) }
        context.insert(category)
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
        add(612, .expense, seeded("flight"), daysAgo: 40).trip = trip
        return container
    }()
}
