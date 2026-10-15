import Foundation

nonisolated struct CategoryShortcut: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let symbol: String
    let crayon: Crayon

    static var all: [CategoryShortcut] {
        get {
            guard let data = UserDefaults.appGroup?.data(forKey: DefaultsKey.widgetCategories) else { return [] }
            return (try? JSONDecoder().decode([CategoryShortcut].self, from: data)) ?? []
        }
        set {
            UserDefaults.appGroup?.set(try? JSONEncoder().encode(newValue), forKey: DefaultsKey.widgetCategories)
        }
    }
}
