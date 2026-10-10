nonisolated enum CSV {
    /// Builds RFC 4180 text with a UTF-8 byte order mark, so Excel reads non-ASCII text correctly.
    static func make(_ rows: [[String]]) -> String {
        "\u{FEFF}" + rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var previous: Character?

        func endField() {
            row.append(unescape(field))
            field = ""
        }

        func endRow() {
            endField()
            if row != [""] { rows.append(row) }
            row = []
        }

        for character in text.trimmingPrefix("\u{FEFF}") {
            if isQuoted {
                if character == "\"" { isQuoted = false } else { field.append(character) }
            } else if character == "\"" {
                if previous == "\"" { field.append("\"") }
                isQuoted = true
            } else if character == "," {
                endField()
            } else if character.isNewline {
                endRow()
            } else {
                field.append(character)
            }
            previous = character
        }
        endRow()
        return rows
    }

    private static let formulaStarts = "=+-@\t\r"

    // Spreadsheets run cells that start with these characters as formulas: https://owasp.org/www-community/attacks/CSV_Injection
    private static func escape(_ field: String) -> String {
        let field = field.first.map { formulaStarts.contains($0) } == true ? "'" + field : field
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacing("\"", with: "\"\"") + "\""
    }

    private static func unescape(_ field: String) -> String {
        guard field.first == "'", let second = field.dropFirst().first, formulaStarts.contains(second) else { return field }
        return String(field.dropFirst())
    }
}
