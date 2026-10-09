import Foundation

/// A category as the widget sees it. Mer writes the list to the App Group, because the widget cannot open the SwiftData store.
nonisolated struct CategoryShortcut: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let symbol: String
    let crayon: Crayon

    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.polo.Mer") }

    static var all: [CategoryShortcut] {
        get {
            guard let data = defaults?.data(forKey: DefaultsKey.widgetCategories) else { return [] }
            return (try? JSONDecoder().decode([CategoryShortcut].self, from: data)) ?? []
        }
        set {
            defaults?.set(try? JSONEncoder().encode(newValue), forKey: DefaultsKey.widgetCategories)
        }
    }
}
