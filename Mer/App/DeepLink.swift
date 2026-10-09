import Foundation

nonisolated enum DeepLink: Equatable {
    case newEntry(categoryID: UUID?)

    init?(_ url: URL) {
        guard url.scheme == "mer", url.host() == "new-entry" else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let categoryID = query?.first { $0.name == "category" }?.value.flatMap(UUID.init(uuidString:))
        self = .newEntry(categoryID: categoryID)
    }

    var url: URL {
        switch self {
        case .newEntry(let categoryID):
            var components = URLComponents()
            components.scheme = "mer"
            components.host = "new-entry"
            if let categoryID {
                components.queryItems = [URLQueryItem(name: "category", value: categoryID.uuidString)]
            }
            return components.url!
        }
    }
}
