import Foundation

/// Daily reference rates, cached in `UserDefaults` so conversion also works offline.
@Observable
final class ExchangeRates {
    static let shared = ExchangeRates()

    /// Units of each currency per 1 US dollar, keyed by uppercase ISO 4217 code.
    private var perDollar: [String: Double]
    private var fetchedAt: Date?
    private var isFetching = false

    private init() {
        let defaults = UserDefaults.standard
        perDollar = defaults.dictionary(forKey: DefaultsKey.exchangeRates) as? [String: Double] ?? [:]
        fetchedAt = defaults.object(forKey: DefaultsKey.exchangeRatesDate) as? Date
    }

    /// How many units of `target` one unit of `source` buys.
    func rate(from source: String, to target: String) -> Decimal? {
        guard let source = perDollar[source], let target = perDollar[target], source > 0 else { return nil }
        return Decimal(target / source)
    }

    func refreshIfStale() async {
        let twelveHours: TimeInterval = 12 * 60 * 60
        if let fetchedAt, Date.now.timeIntervalSince(fetchedAt) < twelveHours { return }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        for source in Self.sources {
            guard let (data, _) = try? await URLSession.shared.data(from: source),
                let response = try? JSONDecoder().decode(DollarRates.self, from: data)
            else { continue }
            perDollar = Dictionary(response.usd.map { ($0.key.uppercased(), $0.value) }) { first, _ in first }
            fetchedAt = .now
            UserDefaults.standard.set(perDollar, forKey: DefaultsKey.exchangeRates)
            UserDefaults.standard.set(fetchedAt, forKey: DefaultsKey.exchangeRatesDate)
            return
        }
    }

    // Free and keyless. The API's README names the second URL as the fallback: https://github.com/fawazahmed0/exchange-api
    private static let sources = [
        URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json")!,
        URL(string: "https://latest.currency-api.pages.dev/v1/currencies/usd.json")!,
    ]

    private nonisolated struct DollarRates: Decodable {
        let usd: [String: Double]
    }
}
