import Foundation
import SwiftUI

nonisolated enum Money {
    static let defaultCode = Locale.current.currency?.identifier ?? "USD"

    static var currentCode: String {
        UserDefaults.standard.string(forKey: DefaultsKey.currencyCode) ?? defaultCode
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

    var plainString: String { NSDecimalNumber(decimal: self).stringValue }

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
