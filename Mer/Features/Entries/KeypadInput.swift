import Foundation

nonisolated enum KeypadOperator: Character {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"
}

nonisolated enum KeypadKey: Hashable {
    case digit(Int)
    case dot, delete
    case op(KeypadOperator)
}

nonisolated enum KeypadInput {
    static let maxIntegerDigits = 9

    static func apply(_ key: KeypadKey, to text: String) -> String {
        let number = currentNumber(text)
        switch key {
        case .delete:
            return String(text.dropLast())
        case .op(let op):
            guard let last = text.last else { return text }
            return (isOperator(last) ? String(text.dropLast()) : text) + String(op.rawValue)
        case .dot:
            if number.contains(".") { return text }
            return number.isEmpty ? text + "0." : text + "."
        case .digit(let digit):
            if let dot = number.firstIndex(of: ".") {
                return number[number.index(after: dot)...].count >= 2 ? text : text + String(digit)
            }
            if number == "0" { return String(text.dropLast()) + String(digit) }
            return number.count >= maxIntegerDigits ? text : text + String(digit)
        }
    }

    static func amount(_ text: String) -> Decimal? {
        guard let value = evaluate(text)?.rounded(scale: 2), value > 0 else { return nil }
        return value
    }

    static func evaluate(_ text: String) -> Decimal? {
        var numbers: [Decimal] = []
        var ops: [KeypadOperator] = []
        for token in tokens(text) {
            switch token {
            case .number(let string):
                guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
                numbers.append(value)
            case .op(let op):
                ops.append(op)
            }
        }
        guard var term = numbers.first else { return nil }
        var sum = Decimal.zero
        var sign = Decimal(1)
        for (op, value) in zip(ops, numbers.dropFirst()) {
            switch op {
            case .multiply:
                term *= value
            case .divide:
                guard value != 0 else { return nil }
                term /= value
            case .add, .subtract:
                sum += sign * term
                sign = op == .add ? 1 : -1
                term = value
            }
        }
        return sum + sign * term
    }

    static func hasOperator(_ text: String) -> Bool {
        text.contains(where: isOperator)
    }

    static func display(_ text: String, locale: Locale = .current) -> String {
        guard !text.isEmpty else { return "0" }
        return tokens(text).map { token in
            switch token {
            case .number(let string): formatNumber(string, locale: locale)
            case .op(let op): " \(op.rawValue) "
            }
        }
        .joined()
        .trimmingCharacters(in: .whitespaces)
    }

    private enum Token {
        case number(String)
        case op(KeypadOperator)
    }

    private static func tokens(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var number = ""
        for character in text {
            if let op = KeypadOperator(rawValue: character) {
                if !number.isEmpty { tokens.append(.number(number)) }
                number = ""
                tokens.append(.op(op))
            } else {
                number.append(character)
            }
        }
        if !number.isEmpty { tokens.append(.number(number)) }
        return tokens
    }

    private static func isOperator(_ character: Character) -> Bool {
        KeypadOperator(rawValue: character) != nil
    }

    private static func currentNumber(_ text: String) -> Substring {
        guard let last = text.lastIndex(where: isOperator) else { return text[...] }
        return text[text.index(after: last)...]
    }

    private static func formatNumber(_ text: String, locale: Locale) -> String {
        let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = Int(parts[0]).map { $0.formatted(.number.locale(locale)) } ?? String(parts[0])
        guard parts.count == 2 else { return whole }
        return whole + (locale.decimalSeparator ?? ".") + parts[1]
    }
}
