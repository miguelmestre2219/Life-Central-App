import Foundation

/// Amounts are stored as whole minor units (pence, cents, yen) in their own currency.
/// Integers keep rows small and avoid rounding drift; this file turns them into text and back.
enum CurrencyInfo {
    private static var digitsCache: [String: Int] = [:]
    private static var symbolCache: [String: String] = [:]

    /// Every ISO currency the phone knows about, sorted by name.
    static let allCodes: [String] = {
        let codes = Set(Locale.Currency.isoCurrencies.map(\.identifier))
            .filter { name($0) != $0 }
        return codes.sorted { name($0) < name($1) }
    }()

    static func fractionDigits(_ code: String) -> Int {
        if let cached = digitsCache[code] { return cached }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits
        digitsCache[code] = digits
        return digits
    }

    static func symbol(_ code: String) -> String {
        if let cached = symbolCache[code] { return cached }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = .current
        let symbol = formatter.currencySymbol ?? code
        symbolCache[code] = symbol
        return symbol
    }

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    /// The currency used in a country, from its two-letter region code ("PT" -> "EUR").
    static func code(forCountry region: String) -> String? {
        Locale(identifier: "en_\(region.uppercased())").currency?.identifier
    }

    /// Countries that use a currency, for searching "Portugal" and finding EUR.
    static func countries(using code: String) -> [String] {
        countryIndex[code] ?? []
    }

    private static let countryIndex: [String: [String]] = {
        var index: [String: [String]] = [:]
        for region in Locale.Region.isoRegions where region.subRegions.isEmpty {
            guard region.identifier.count == 2,
                  let code = Locale(identifier: "en_\(region.identifier)").currency?.identifier,
                  let name = Locale.current.localizedString(forRegionCode: region.identifier) else { continue }
            index[code, default: []].append(name)
        }
        return index
    }()
}

enum MoneyFormat {
    static func decimal(_ minor: Int, _ code: String) -> Decimal {
        Decimal(minor) / pow(10, CurrencyInfo.fractionDigits(code))
    }

    static func minor(from value: Decimal, _ code: String) -> Int {
        var scaled = value * pow(10, CurrencyInfo.fractionDigits(code))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    /// "£1,234.50". With `whole`, drops the pence when they are zero ("£600").
    static func string(_ minor: Int, _ code: String, whole: Bool = false, signed: Bool = false) -> String {
        let value = decimal(minor, code)
        var style = Decimal.FormatStyle.Currency(code: code, locale: .current)
        let scale = Int(pow(10.0, Double(CurrencyInfo.fractionDigits(code))))
        if whole && minor % scale == 0 {
            style = style.precision(.fractionLength(0))
        }
        let text = value.formatted(style)
        return signed && minor > 0 ? "+" + text : text
    }

    /// Text for an editable field: "12.5" rather than "£12.50".
    static func editString(_ minor: Int, _ code: String) -> String {
        guard minor != 0 else { return "" }
        let value = decimal(minor, code)
        return value.formatted(.number.precision(.fractionLength(0...CurrencyInfo.fractionDigits(code))).grouping(.never))
    }

    /// Reads what someone typed ("12,50", "1 200.5", "€8") into minor units.
    static func parse(_ text: String, _ code: String) -> Int? {
        let separator = Locale.current.decimalSeparator ?? "."
        var cleaned = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        if separator == "," {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }
        guard !cleaned.isEmpty, let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return minor(from: value, code)
    }

    /// Converts minor units between currencies. `rate` is how many `to` units one `from` unit buys.
    static func convert(_ minor: Int, from: String, to: String, rate: Double) -> Int {
        guard from != to else { return minor }
        let fromScale = pow(10, Double(CurrencyInfo.fractionDigits(from)))
        let toScale = pow(10, Double(CurrencyInfo.fractionDigits(to)))
        return Int((Double(minor) / fromScale * rate * toScale).rounded())
    }
}
