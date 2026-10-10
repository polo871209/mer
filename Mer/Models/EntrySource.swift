import Foundation

nonisolated enum EntrySource: Hashable {
    case account(String)
    case trip(UUID)

    var all: Predicate<Entry> {
        switch self {
        case .account(let code):
            return #Predicate { $0.accountCode == code }
        case .trip(let id):
            return #Predicate { $0.trip?.uuid == id }
        }
    }

    var counted: Predicate<Entry> {
        switch self {
        case .account(let code):
            return #Predicate { $0.accountCode == code && $0.trip == nil }
        case .trip:
            return all
        }
    }
}
