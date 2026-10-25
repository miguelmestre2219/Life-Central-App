import Foundation
import SwiftData

enum TripStatus: String, CaseIterable, Identifiable {
    case idea, booked
    var id: String { rawValue }
    var title: String { self == .idea ? "Idea" : "Booked" }
}

@Model
final class Trip {
    var name: String = ""
    var destination: String = ""
    /// Two-letter country code of the main destination, used for currency and maps.
    var countryCode: String = ""
    /// Extra cities for multi-city trips, one per line.
    var otherCitiesText: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var currencyCode: String = "GBP"
    /// Budget in the home currency.
    var budgetMinor: Int = 0
    var statusRaw: String = TripStatus.booked.rawValue
    var colorHex: String = "1D4ED8"
    var notes: String = ""
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \TripItem.trip)
    var items: [TripItem]? = []
    @Relationship(deleteRule: .cascade, inverse: \PackingItem.trip)
    var packing: [PackingItem]? = []
    @Relationship(deleteRule: .nullify, inverse: \MoneyEntry.trip)
    var entries: [MoneyEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \Document.trip)
    var documents: [Document]? = []
    @Relationship(deleteRule: .nullify, inverse: \TodoItem.trip)
    var tasks: [TodoItem]? = []

    init(name: String, destination: String, countryCode: String, startDate: Date, endDate: Date, currencyCode: String) {
        self.name = name
        self.destination = destination
        self.countryCode = countryCode
        self.startDate = startDate.startOfDay
        self.endDate = endDate.startOfDay
        self.currencyCode = currencyCode
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .booked }
        set { statusRaw = newValue.rawValue }
    }

    var days: [Date] { startDate.days(through: endDate) }
    var dayCount: Int { days.count }
    var isPast: Bool { endDate.startOfDay < Date.now.startOfDay }
    var isUnderway: Bool { startDate <= Date.now && !isPast }

    var otherCities: [String] {
        otherCitiesText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func items(on day: Date) -> [TripItem] {
        (items ?? []).filter { $0.day.isSameDay(as: day) }.sorted(by: TripItem.order)
    }

    /// Days that have at least one plan item.
    var plannedDayCount: Int {
        days.filter { !items(on: $0).isEmpty }.count
    }

    var spentHomeMinor: Int {
        (entries ?? []).filter { !$0.isIncome }.reduce(0) { $0 + $1.homeAmountMinor }
    }

    /// Costs of plan items not yet paid (no Money entry yet), in the home currency.
    var plannedHomeMinor: Int {
        (items ?? []).filter { ($0.moneyEntries ?? []).isEmpty }.reduce(0) { $0 + $1.costHomeMinor }
    }

    var packedCount: Int { (packing ?? []).filter(\.isPacked).count }
}

enum TripItemKind: String, CaseIterable, Identifiable {
    case activity, food, transport, stay, flight, free
    var id: String { rawValue }
    var title: String {
        switch self {
        case .activity: "Activity"
        case .food: "Food"
        case .transport: "Transport"
        case .stay: "Stay"
        case .flight: "Flight"
        case .free: "Free time"
        }
    }
    var icon: String {
        switch self {
        case .activity: "ticket"
        case .food: "fork.knife"
        case .transport: "tram"
        case .stay: "bed.double"
        case .flight: "airplane"
        case .free: "sun.max"
        }
    }
}

enum BookingStatus: String, CaseIterable, Identifiable {
    case none, toBook, booked
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Nothing to book"
        case .toBook: "To book"
        case .booked: "Booked"
        }
    }
}

@Model
final class TripItem {
    var day: Date = Date.now
    /// Clock time on `day`; nil means "any time" and sorts to the end.
    var startTime: Date?
    var durationMinutes: Int = 60
    var kindRaw: String = TripItemKind.activity.rawValue
    var title: String = ""
    var placeName: String = ""
    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    var costMinor: Int = 0
    var costCurrency: String = "EUR"
    var costRateToHome: Double = 1
    var bookingRaw: String = BookingStatus.none.rawValue
    var notes: String = ""
    var sortOrder: Int = 0

    var trip: Trip?
    @Relationship(deleteRule: .nullify, inverse: \MoneyEntry.tripItem)
    var moneyEntries: [MoneyEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \Document.tripItem)
    var documents: [Document]? = []

    init(day: Date, kind: TripItemKind, title: String) {
        self.day = day.startOfDay
        self.kindRaw = kind.rawValue
        self.title = title
    }

    var kind: TripItemKind {
        get { TripItemKind(rawValue: kindRaw) ?? .activity }
        set { kindRaw = newValue.rawValue }
    }

    var booking: BookingStatus {
        get { BookingStatus(rawValue: bookingRaw) ?? .none }
        set { bookingRaw = newValue.rawValue }
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }

    var costHomeMinor: Int {
        MoneyFormat.convert(costMinor, from: costCurrency, to: AppSettings.homeCurrency, rate: costRateToHome)
    }

    var timeText: String {
        guard let startTime else { return "Any time" }
        return DateText.time(startTime)
    }

    static func order(_ a: TripItem, _ b: TripItem) -> Bool {
        switch (a.startTime, b.startTime) {
        case let (x?, y?):
            let cx = Calendar.app.dateComponents([.hour, .minute], from: x)
            let cy = Calendar.app.dateComponents([.hour, .minute], from: y)
            let mx = (cx.hour ?? 0) * 60 + (cx.minute ?? 0)
            let my = (cy.hour ?? 0) * 60 + (cy.minute ?? 0)
            return mx == my ? a.sortOrder < b.sortOrder : mx < my
        case (_?, nil): return true
        case (nil, _?): return false
        default: return a.sortOrder < b.sortOrder
        }
    }
}

@Model
final class PackingItem {
    var name: String = ""
    var group: String = "Other"
    var isPacked: Bool = false
    var sortOrder: Int = 0
    var trip: Trip?

    init(name: String, group: String, sortOrder: Int = 0) {
        self.name = name
        self.group = group
        self.sortOrder = sortOrder
    }

    static let groups = ["Documents", "Clothes", "Toiletries", "Tech", "Other"]
}

/// A place saved from Explore, not yet on a trip day.
@Model
final class SavedPlace {
    var name: String = ""
    var note: String = ""
    var address: String = ""
    var countryCode: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var createdAt: Date = Date.now

    init(name: String, address: String, countryCode: String, latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
    }
}

@Model
final class VisitedCountry {
    var countryCode: String = ""
    var addedAt: Date = Date.now

    init(countryCode: String) {
        self.countryCode = countryCode
    }
}

enum Country {
    static func name(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    static func flag(_ code: String) -> String {
        code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String(Character($0)) }.joined()
    }

    /// All countries, sorted by name.
    static let all: [String] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && Int($0) == nil && Locale.current.localizedString(forRegionCode: $0) != nil }
        .sorted { name($0) < name($1) }
}
