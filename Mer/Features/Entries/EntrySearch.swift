import Foundation

struct EntrySearch {
    private let query: SearchQuery

    init?(_ text: String) {
        guard let query = SearchQuery(text) else { return nil }
        self.query = query
    }

    func matches(_ entry: Entry) -> Bool {
        let amounts = ([entry.amount] + [entry.originalAmount].compactMap(\.self)).flatMap(Self.amountTexts)
        return query.matches([entry.note, entry.category.displayName, entry.trip?.name ?? ""]) { term in
            guard let number = Self.numberText(term) else { return false }
            return amounts.contains { $0.hasPrefix(number) }
        }
    }

    private static func amountTexts(_ amount: Decimal) -> [String] {
        let precision = Decimal.FormatStyle.number.precision(.fractionLength(2...))
        let fixed = amount.formatted(precision.grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
        return [fixed, fixed.replacing(".", with: ","), amount.formatted(precision), amount.description]
    }

    private static func numberText(_ term: String) -> String? {
        let kept = term.filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }
        return kept.contains(where: \.isNumber) ? kept : nil
    }
}
