import Foundation

/// A description
nonisolated enum DefaultsKey {
    static let mainCurrency = "currencyCode"
    static let otherCurrencies = "otherCurrencies"
    static let exchangeRates = "exchangeRates"
    static let exchangeRatesDate = "exchangeRatesDate"
    static let lockEnabled = "lockEnabled"
    static let addButtonOnLeft = "addButtonOnLeft"
    static let widgetCategories = "widgetCategories"
    static let widgetBudget = "widgetBudget"
    static let budgetEnabled = "budgetEnabled"
    static let monthlyBudget = "monthlyBudget"
    static let tripCategoriesAdded = "tripCategoriesAdded"
}

nonisolated extension UserDefaults {
    static var appGroup: UserDefaults? { UserDefaults(suiteName: "group.com.polo.Mer") }
}
