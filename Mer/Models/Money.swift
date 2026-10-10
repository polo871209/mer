import SwiftUI
import Synchronization

nonisolated enum Money {
    static let defaultCode = Locale.current.currency?.identifier ?? "USD"

    static var mainCode: String {
        UserDefaults.standard.string(forKey: DefaultsKey.mainCurrency) ?? defaultCode
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    static let fractionDigits = 2

    private static let wholeAmountFractionDigitsByCode = Mutex<[String: Int]>([:])

    fileprivate static func wholeAmountFractionDigits(_ code: String) -> Int {
        wholeAmountFractionDigitsByCode.withLock { byCode in
            if let digits = byCode[code] { return digits }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            let digits = min(formatter.maximumFractionDigits, fractionDigits)
            byCode[code] = digits
            return digits
        }
    }
}

nonisolated struct Accounts {
    let main: String
    let others: [String]

    init(main: String, others: [String]) {
        self.main = main
        self.others = others.filter { $0 != main }
    }

    init(main: String, storedOthers: String) {
        self.init(main: main, others: storedOthers.split(separator: ",").map(String.init))
    }

    static var stored: Accounts {
        Accounts(main: Money.mainCode, storedOthers: UserDefaults.standard.string(forKey: DefaultsKey.otherCurrencies) ?? "")
    }

    var storedOthers: String { others.joined(separator: ",") }

    var all: [String] { [main] + others }

    func makingMain(_ code: String) -> Accounts {
        Accounts(main: code, others: [main] + others)
    }

    func adding(_ code: String) -> Accounts {
        all.contains(code) ? self : Accounts(main: main, others: others + [code])
    }

    func removing(_ code: String) -> Accounts {
        Accounts(main: main, others: others.filter { $0 != code })
    }

    func account(for code: String) -> String {
        all.contains(code) ? code : main
    }
}

nonisolated extension Decimal {
    func money(_ code: String) -> String {
        formatted(currencyStyle(code))
    }

    func signedMoney(_ code: String) -> String {
        formatted(currencyStyle(code).sign(strategy: .always()))
    }

    private func currencyStyle(_ code: String) -> Decimal.FormatStyle.Currency {
        let isWhole = self == rounded(scale: 0)
        let digits = isWhole ? Money.wholeAmountFractionDigits(code) : Money.fractionDigits
        return Decimal.FormatStyle.Currency(code: code).precision(.fractionLength(digits))
    }

    var double: Double { NSDecimalNumber(decimal: self).doubleValue }

    func rounded(scale: Int) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}

extension EnvironmentValues {
    @Entry var currencyCode: String = Money.defaultCode
}
