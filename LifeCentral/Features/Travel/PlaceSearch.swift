import Foundation
import MapKit
import Observation

/// A place found online through Apple Maps.
struct FoundPlace: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let countryCode: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, address: String, countryCode: String, latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
    }

    init(item: MKMapItem) {
        let placemark = item.placemark
        name = item.name ?? placemark.locality ?? placemark.country ?? "Place"
        let parts = [placemark.thoroughfare, placemark.locality, placemark.country].compactMap { $0 }
        address = parts.filter { $0 != item.name }.joined(separator: ", ")
        countryCode = placemark.isoCountryCode ?? ""
        latitude = placemark.coordinate.latitude
        longitude = placemark.coordinate.longitude
    }
}

/// Searches Apple Maps as you type. Needs internet; when offline it says so
/// and the forms still accept a typed name.
@Observable
final class PlaceSearch {
    var query = "" {
        didSet { schedule() }
    }
    private(set) var results: [FoundPlace] = []
    private(set) var isSearching = false
    private(set) var offline = false
    /// Bias results towards this area (the trip's city), if set.
    var region: MKCoordinateRegion?
    /// Limit to cities and countries, for picking a trip destination.
    var citiesOnly = false

    private var task: Task<Void, Never>?

    private func schedule() {
        task?.cancel()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2 else {
            results = []
            return
        }
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await run(text)
        }
    }

    @MainActor
    private func run(_ text: String) async {
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        if let region { request.region = region }
        if citiesOnly { request.resultTypes = .address }
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems.prefix(12).map(FoundPlace.init(item:))
            offline = false
        } catch {
            results = []
            offline = (error as? URLError) != nil || (error as NSError).domain == MKErrorDomain
        }
    }
}
