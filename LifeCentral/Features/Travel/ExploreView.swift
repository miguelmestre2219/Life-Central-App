import SwiftUI
import SwiftData
import MapKit

/// Find places, save them for later, and keep track of countries visited.
struct ExploreView: View {
    enum Pin: Hashable {
        case found(FoundPlace)
        case saved(SavedPlace)

        var foundPlace: FoundPlace? {
            if case .found(let place) = self { return place }
            return nil
        }

        var savedPlace: SavedPlace? {
            if case .saved(let place) = self { return place }
            return nil
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query(sort: \SavedPlace.createdAt, order: .reverse) private var saved: [SavedPlace]
    @Query private var visited: [VisitedCountry]
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    @State private var search = PlaceSearch()
    @State private var position: MapCameraPosition = .automatic
    @State private var selection: Pin?
    @State private var addToTrip: FoundPlace?
    @State private var planTrip: FoundPlace?
    @State private var showCountryPicker = false
    @State private var pickedCountry = ""

    private let color = Area.travel.color

    /// Countries ticked by hand plus every country of a past trip.
    private var countries: [String] {
        let fromTrips = trips.filter(\.isPast).map(\.countryCode).filter { !$0.isEmpty }
        return Array(Set(visited.map(\.countryCode) + fromTrips)).sorted { Country.name($0) < Country.name($1) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                map
                if let selection { selectedCard(selection) }
                if !search.results.isEmpty { results }
                savedPlaces
                visitedCountries
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search places")
        .onChange(of: search.results) { _, found in
            guard !found.isEmpty else { return }
            fit(found.map(\.coordinate))
        }
        .sheet(item: $addToTrip) { place in
            TripItemForm(item: nil, presetPlace: place)
        }
        .sheet(item: $planTrip) { place in
            TripForm(trip: nil, presetPlace: place)
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPicker(selection: $pickedCountry) { code in
                if !visited.contains(where: { $0.countryCode == code }) {
                    context.insert(VisitedCountry(countryCode: code))
                }
            }
        }
    }

    private var map: some View {
        Map(position: $position, selection: $selection) {
            ForEach(search.results) { place in
                Marker(place.name, coordinate: place.coordinate)
                    .tint(.red)
                    .tag(Pin.found(place))
            }
            ForEach(saved) { place in
                Marker(place.name, systemImage: "star.fill", coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                    .tint(color)
                    .tag(Pin.saved(place))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .including([.museum, .park, .nationalPark, .beach, .restaurant, .cafe])))
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if search.offline {
                Text("Maps and search need internet")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
            }
        }
    }

    private func selectedCard(_ pin: Pin) -> some View {
        let place = pin.foundPlace
        let savedPlace = pin.savedPlace
        let name = place?.name ?? savedPlace?.name ?? ""
        let address = place?.address ?? savedPlace?.address ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                if !address.isEmpty { Text(address).font(.footnote).foregroundStyle(.secondary) }
            }
            HStack(spacing: 8) {
                if let place {
                    Button { save(place) } label: { Label("Save", systemImage: "star") }
                }
                Button { addToTrip = place ?? savedPlace.map(asFoundPlace) } label: { Label("Add to trip", systemImage: "calendar.badge.plus") }
                Button { planTrip = place ?? savedPlace.map(asFoundPlace) } label: { Label("Plan a trip", systemImage: "airplane") }
            }
            .buttonStyle(.bordered)
            .tint(color)
            .font(.footnote.weight(.semibold))
            .labelStyle(.titleAndIcon)
            Button {
                let query = place.map { "\($0.latitude),\($0.longitude)" } ?? savedPlace.map { "\($0.latitude),\($0.longitude)" } ?? name
                if let url = GoogleMapsLink.search(query) { openURL(url) }
            } label: {
                Label("Open in Google Maps", systemImage: "arrow.up.right.square").font(.footnote)
            }
            .tint(color)
        }
        .card()
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Results").padding(.bottom, 4)
            ForEach(search.results) { place in
                Button {
                    selection = .found(place)
                    fit([place.coordinate])
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if !place.countryCode.isEmpty { Text(Country.flag(place.countryCode)) }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private var savedPlaces: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Saved places").padding(.bottom, 4)
            if saved.isEmpty {
                Text("Search for somewhere and tap Save to keep it for a future trip.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            ForEach(saved) { place in
                Button {
                    selection = .saved(place)
                    fit([CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)])
                } label: {
                    HStack {
                        Image(systemName: "star.fill").foregroundStyle(color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.name).font(.subheadline).foregroundStyle(.primary)
                            if !place.address.isEmpty {
                                Text(place.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        if !place.countryCode.isEmpty { Text(Country.flag(place.countryCode)) }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Remove", role: .destructive) {
                        if selection == .saved(place) { selection = nil }
                        context.delete(place)
                    }
                }
            }
        }
        .card()
    }

    private var visitedCountries: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Countries visited")
                Button { showCountryPicker = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .tint(color)
                    .accessibilityLabel("Add a country")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(countries.count)").font(.display(34))
                Text(countries.count == 1 ? "country" : "countries").foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                ForEach(countries, id: \.self) { code in
                    Text("\(Country.flag(code)) \(Country.name(code))")
                        .font(.footnote)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(color.opacity(0.1), in: Capsule())
                        .contextMenu {
                            if let stored = visited.first(where: { $0.countryCode == code }) {
                                Button("Remove", role: .destructive) { context.delete(stored) }
                            }
                        }
                }
            }
            Text("Past trips count automatically. Add anywhere else you've been with +.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }

    private func save(_ place: FoundPlace) {
        guard !saved.contains(where: { $0.name == place.name && abs($0.latitude - place.latitude) < 0.0005 }) else { return }
        context.insert(SavedPlace(name: place.name, address: place.address, countryCode: place.countryCode,
                                  latitude: place.latitude, longitude: place.longitude))
    }

    private func asFoundPlace(_ place: SavedPlace) -> FoundPlace {
        FoundPlace(name: place.name, address: place.address, countryCode: place.countryCode,
                   latitude: place.latitude, longitude: place.longitude)
    }

    private func fit(_ points: [CLLocationCoordinate2D]) {
        guard !points.isEmpty else { return }
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.02),
                                    longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.02))
        withAnimation { position = .region(MKCoordinateRegion(center: center, span: span)) }
    }
}
