import Foundation
import SwiftData
import CoreLocation

extension Trip {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Day number (1-based) of a date within the trip.
    func dayNumber(_ day: Date) -> Int {
        (days.firstIndex { $0.isSameDay(as: day) } ?? 0) + 1
    }

    /// Plan items that have a place on the map, in day and time order.
    func mappedItems(on day: Date? = nil) -> [TripItem] {
        let chosen = day.map { [$0] } ?? days
        return chosen.flatMap { items(on: $0) }.filter(\.hasLocation)
    }

    var plannedCostHomeMinor: Int {
        (items ?? []).reduce(0) { $0 + $1.costHomeMinor }
    }
}

extension TripItem {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isPaid: Bool { !(moneyEntries ?? []).isEmpty }

    /// Text for Google Maps when the item has no coordinates.
    var searchText: String {
        [placeName.isEmpty ? title : placeName, address].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Adds this item's cost to Money, linked to the trip and the item.
    @MainActor
    @discardableResult
    func recordPayment(in context: ModelContext) -> MoneyEntry? {
        guard costMinor > 0 else { return nil }
        let entry = MoneyEntry(date: day, amountMinor: costMinor, currencyCode: costCurrency,
                               rateToHome: costRateToHome, note: title)
        context.insert(entry)
        entry.trip = trip
        entry.tripItem = self
        let travel = "Travel"
        let descriptor = FetchDescriptor<MoneyCategory>(predicate: #Predicate { $0.name == travel && !$0.isIncome })
        entry.category = (try? context.fetch(descriptor))?.first
        return entry
    }
}

/// Hands a trip over to Google Maps. Everything here is a one-way copy:
/// changes made in Google Maps do not come back.
enum GoogleMapsLink {
    enum Mode: String, CaseIterable, Identifiable {
        case transit, walking, driving
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .transit: "tram"
            case .walking: "figure.walk"
            case .driving: "car"
            }
        }
    }

    /// Google allows up to nine stops between the start and the end.
    static let maxWaypoints = 9

    private static func location(_ item: TripItem) -> String {
        if let latitude = item.latitude, let longitude = item.longitude {
            return "\(latitude),\(longitude)"
        }
        return item.searchText
    }

    static func directions(_ stops: [TripItem], mode: Mode) -> URL? {
        guard let first = stops.first, let last = stops.last, stops.count >= 2 else {
            return stops.first.flatMap(place)
        }
        var parts = URLComponents(string: "https://www.google.com/maps/dir/")!
        var query = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "origin", value: location(first)),
            URLQueryItem(name: "destination", value: location(last)),
            URLQueryItem(name: "travelmode", value: mode.rawValue),
        ]
        let middle = stops.dropFirst().dropLast().prefix(maxWaypoints)
        if !middle.isEmpty {
            query.append(URLQueryItem(name: "waypoints", value: middle.map(location).joined(separator: "|")))
        }
        parts.queryItems = query
        return parts.url
    }

    static func place(_ item: TripItem) -> URL? {
        search(location(item))
    }

    static func search(_ text: String) -> URL? {
        var parts = URLComponents(string: "https://www.google.com/maps/search/")!
        parts.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: text)]
        return parts.url
    }
}

enum TripExport {
    /// A KML file of the whole trip, one folder per day, for Google My Maps.
    static func kmlFile(for trip: Trip) -> URL? {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<kml xmlns="http://www.opengis.net/kml/2.2"><Document>"#,
            "<name>\(escape(trip.name))</name>",
        ]
        for (index, day) in trip.days.enumerated() {
            let stops = trip.mappedItems(on: day)
            guard !stops.isEmpty else { continue }
            lines.append("<Folder><name>Day \(index + 1) · \(escape(DateText.relativeDay(day)))</name>")
            for item in stops {
                guard let latitude = item.latitude, let longitude = item.longitude else { continue }
                let detail = [item.timeText, item.kind.title, item.address, item.notes].filter { !$0.isEmpty }.joined(separator: " · ")
                lines.append("<Placemark><name>\(escape(item.title))</name><description>\(escape(detail))</description>")
                lines.append("<Point><coordinates>\(longitude),\(latitude),0</coordinates></Point></Placemark>")
            }
            if stops.count > 1 {
                let path = stops.compactMap { item in
                    item.latitude.flatMap { lat in item.longitude.map { "\($0),\(lat),0" } }
                }.joined(separator: " ")
                lines.append("<Placemark><name>Day \(index + 1) route</name><LineString><tessellate>1</tessellate><coordinates>\(path)</coordinates></LineString></Placemark>")
            }
            lines.append("</Folder>")
        }
        lines.append("</Document></kml>")

        let safeName = trip.name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName.isEmpty ? "Trip" : safeName).kml")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// The plan as plain text, for sending to a friend.
    static func itinerary(for trip: Trip) -> String {
        var lines = ["\(trip.name) · \(DateText.range(trip.startDate, trip.endDate))"]
        for (index, day) in trip.days.enumerated() {
            let items = trip.items(on: day)
            guard !items.isEmpty else { continue }
            lines.append("")
            lines.append("Day \(index + 1), \(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
            for item in items {
                var line = "• \(item.startTime == nil ? "" : item.timeText + "  ")\(item.title)"
                if !item.placeName.isEmpty && item.placeName != item.title { line += " (\(item.placeName))" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
