import Foundation

/// Typo-tolerant search that ignores case, accents, and character width.
nonisolated struct SearchQuery {
    private let terms: [String]

    /// Returns `nil` when `text` holds no search terms.
    init?(_ text: String) {
        let terms = text.split(whereSeparator: \.isWhitespace).map { Self.fold(String($0)) }
        guard !terms.isEmpty else { return nil }
        self.terms = terms
    }

    /// True when every term is in one of `fields`, or `alsoMatches` accepts the term.
    func matches(_ fields: [String], alsoMatches: (String) -> Bool = { _ in false }) -> Bool {
        let folded = fields.map(Self.fold)
        let words = folded.flatMap { $0.split { !$0.isLetter && !$0.isNumber }.map(Array.init) }
        return terms.allSatisfy { term in
            if alsoMatches(term) || folded.contains(where: { $0.contains(term) }) { return true }
            let allowedEdits = Self.allowedEdits(forLength: term.count)
            guard allowedEdits > 0, term.contains(where: \.isLetter) else { return false }
            let termCharacters = Array(term)
            return words.contains { Self.prefixDistance(termCharacters, $0, limit: allowedEdits) <= allowedEdits }
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }

    private static func allowedEdits(forLength length: Int) -> Int {
        switch length {
        case ..<4: 0
        case ..<8: 1
        default: 2
        }
    }

    /// Smallest optimal string alignment distance between `term` and a prefix of `word`, so a half-typed word with a typo still matches.
    private static func prefixDistance(_ term: [Character], _ word: [Character], limit: Int) -> Int {
        let shortest = max(0, term.count - limit)
        let longest = min(word.count, term.count + limit)
        guard shortest <= longest else { return .max }
        return (shortest...longest).map { distance(term, Array(word[..<$0])) }.min() ?? .max
    }

    private static func distance(_ a: [Character], _ b: [Character]) -> Int {
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var table = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { table[i][0] = i }
        for j in 0...b.count { table[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                table[i][j] = min(table[i - 1][j] + 1, table[i][j - 1] + 1, table[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    table[i][j] = min(table[i][j], table[i - 2][j - 2] + 1)
                }
            }
        }
        return table[a.count][b.count]
    }
}
