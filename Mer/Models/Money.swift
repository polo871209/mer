import Foundation
import SwiftUI

nonisolated enum Money {
    static let defaultCode = Locale.current.currency?.identifier ?? "USD"

    static var mainCode: String {
        UserDefaults.standard.string(forKey: DefaultsKey.mainCurrency) ?? defaultCode
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    /// Minor units of an ISO 4217 currency, for example 2 for USD, 0 for JPY, and 3 for KWD.
    static func fractionDigits(_ code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }
}

/// The currencies the user holds money in. An entry in one of these currencies stays in its own account, and an entry in any other currency converts into `main`.
nonisolated struct Accounts {
    let main: String
    let others: [String]

    init(main: String, others: [String]) {
        self.main = main
        self.others = others.filter { $0 != main }
    }

    /// `storedOthers` is the comma-separated list stored under `DefaultsKey.otherCurrencies`.
    init(main: String, storedOthers: String) {
        self.init(main: main, others: storedOthers.split(separator: ",").map(String.init))
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
        formatted(.currency(code: code))
    }

    func signedMoney(_ code: String) -> String {
        formatted(.currency(code: code).sign(strategy: .always()))
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
