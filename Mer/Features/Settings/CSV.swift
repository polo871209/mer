import Foundation

nonisolated enum CSV {
    /// Builds RFC 4180 text with a UTF-8 byte order mark, so Excel reads non-ASCII text correctly.
    static func make(_ rows: [[String]]) -> String {
        "\u{FEFF}" + rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    // Spreadsheets run cells that start with these characters as formulas: https://owasp.org/www-community/attacks/CSV_Injection
    private static func escape(_ field: String) -> String {
        let field = field.first.map { "=+-@\t\r".contains($0) } == true ? "'" + field : field
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
