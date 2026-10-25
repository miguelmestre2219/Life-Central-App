import Foundation
import Observation

/// Daily exchange rates, fetched online and cached so entries can still be
/// converted offline with the last known rate. Every entry keeps the rate it
/// was saved with, so old totals never change when rates move.
@Observable
final class ExchangeRates {
    static let shared = ExchangeRates()

    private(set) var base: String = "GBP"
    /// How many units of each currency one unit of `base` buys.
    private(set) var rates: [String: Double] = [:]
    private(set) var updatedAt: Date?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let storageKey = "exchangeRatesCache"

    private struct Cache: Codable {
        var base: String
        var rates: [String: Double]
        var updatedAt: Date
    }

    private struct Response: Decodable {
        let result: String
        let base_code: String?
        let rates: [String: Double]?
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            base = cache.base
            rates = cache.rates
            updatedAt = cache.updatedAt
        }
    }

    /// How many `to` units one `from` unit buys, or nil if never fetched.
    func rate(from: String, to: String) -> Double? {
        if from == to { return 1 }
        let fromRate = from == base ? 1 : rates[from]
        let toRate = to == base ? 1 : rates[to]
        guard let fromRate, let toRate, fromRate > 0 else { return nil }
        return toRate / fromRate
    }

    var isStale: Bool {
        guard let updatedAt else { return true }
        return Date.now.timeIntervalSince(updatedAt) > 12 * 3600
    }

    @MainActor
    func refreshIfNeeded() async {
        guard isStale || base != AppSettings.homeCurrency else { return }
        await refresh()
    }

    @MainActor
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let home = AppSettings.homeCurrency
        guard let url = URL(string: "https://open.er-api.com/v6/latest/\(home)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(Response.self, from: data)
            guard response.result == "success", let fetched = response.rates else {
                lastError = "Rates are not available right now."
                return
            }
            base = response.base_code ?? home
            rates = fetched
            updatedAt = .now
            lastError = nil
            if let data = try? JSONEncoder().encode(Cache(base: base, rates: rates, updatedAt: .now)) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
        } catch {
            lastError = "Offline. Using rates from \(updatedAt.map { DateText.relativeDay($0) } ?? "never")."
        }
    }
}
