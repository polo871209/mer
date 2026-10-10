import Foundation

nonisolated struct Conversion {
    let account: String
    let rate: Decimal?

    func convert(_ amount: Decimal) -> Decimal? {
        guard let rate else { return nil }
        let converted = (amount * rate).rounded(scale: Money.fractionDigits)
        return converted > 0 ? converted : nil
    }
}

@MainActor
extension Entry {
    func setAmount(_ typed: Decimal, currency: String, accountAmount: Decimal, account: String, trip: Trip?) {
        let snapshot = mainSnapshot(accountAmount: accountAmount, account: account, trip: trip)
        let isConverted = account != currency
        mainAmount = snapshot?.amount
        mainCode = snapshot?.code
        amount = accountAmount
        accountCode = account
        originalAmount = isConverted ? typed : nil
        originalCode = isConverted ? currency : nil
        self.trip = trip
    }

    private func mainSnapshot(accountAmount: Decimal, account: String, trip: Trip?) -> (amount: Decimal, code: String)? {
        let main = Money.mainCode
        guard trip != nil, account != main else { return nil }
        if mainCode == main, accountCode == account, amount == accountAmount, let mainAmount {
            return (mainAmount, main)
        }
        guard let rate = ExchangeRates.shared.rate(from: account, to: main) else { return nil }
        return ((accountAmount * rate).rounded(scale: Money.fractionDigits), main)
    }
}
