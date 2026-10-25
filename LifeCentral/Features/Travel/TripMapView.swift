import SwiftUI
import MapKit

struct TripMapView: View {
    let trip: Trip

    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var day: Date?
    @State private var position: MapCameraPosition = .automatic
    @State private var selected: TripItem?

    init(trip: Trip, initialDay: Date?) {
        self.trip = trip
        _day = State(initialValue: initialDay?.startOfDay)
    }

    private var color: Color { Color(hex: trip.colorHex) }
    private var stops: [TripItem] { trip.mappedItems(on: day) }
    private var unpinned: [TripItem] {
        let chosen = day.map { [$0] } ?? trip.days
        return chosen.flatMap { trip.items(on: $0) }.filter { !$0.hasLocation }
    }

    var body: some View {
        VStack(spacing: 0) {
            map
            panel
        }
        .navigationTitle(day.map { "Day \(trip.dayNumber($0)) map" } ?? "\(trip.name) map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.googleMaps(trip, day)) } label: {
                    Label("Google Maps", systemImage: "arrow.up.right.square")
                }
            }
        }
        .onAppear(perform: fit)
        .onChange(of: day) { _, _ in
            selected = nil
            fit()
        }
    }

    private var map: some View {
        Map(position: $position, selection: $selected) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, item in
                if let coordinate = item.coordinate {
                    Marker(item.title, monogram: Text("\(index + 1)"), coordinate: coordinate)
                        .tint(color)
                        .tag(item)
                }
            }
            ForEach(routeDays, id: \.self) { routeDay in
                let line = trip.mappedItems(on: routeDay).compactMap(\.coordinate)
                if line.count > 1 {
                    MapPolyline(coordinates: line)
                        .stroke(color.opacity(day == nil ? 0.6 : 0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))
                }
            }
            if stops.isEmpty, let center = trip.coordinate {
                Marker(trip.destination, systemImage: "mappin", coordinate: center).tint(color)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .bottomLeading) {
            if let selected {
                selectedCard(selected)
                    .padding(12)
            }
        }
    }

    private var routeDays: [Date] {
        day.map { [$0] } ?? trip.days
    }

    private func selectedCard(_ item: TripItem) -> some View {
        HStack(spacing: 12) {
            IconChip(symbol: item.kind.icon, color: color, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold))
                Text("Day \(trip.dayNumber(item.day)) · \(item.timeText)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if let url = GoogleMapsLink.place(item) { openURL(url) }
            } label: {
                Image(systemName: "arrow.up.right.square").font(.title3)
            }
            .accessibilityLabel("Open in Google Maps")
            Button { router.present(.tripItem(item, trip: trip, day: item.day)) } label: {
                Image(systemName: "pencil.circle").font(.title3)
            }
            .accessibilityLabel("Edit")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var panel: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ChoiceChip(title: "Whole trip", isOn: day == nil, color: color) { day = nil }
                    ForEach(Array(trip.days.enumerated()), id: \.offset) { index, date in
                        ChoiceChip(title: "Day \(index + 1)", isOn: day?.isSameDay(as: date) ?? false, color: color) { day = date }
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if stops.isEmpty {
                        Text("No places with a map pin yet. Add a place to a plan and it shows up here.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, item in
                        Button { focus(item) } label: {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(color, in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title).font(.subheadline).foregroundStyle(.primary)
                                    Text(day == nil ? "Day \(trip.dayNumber(item.day)) · \(item.timeText)" : item.timeText)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if !unpinned.isEmpty {
                        Text("Not on the map: \(unpinned.map(\.title).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    Text("Maps need an internet connection.")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, Theme.gutter)
            }
        }
        .padding(.top, 12)
        .frame(height: 260)
        .background(Theme.background)
    }

    private func focus(_ item: TripItem) {
        guard let coordinate = item.coordinate else { return }
        selected = item
        withAnimation {
            position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
        }
    }

    /// Zooms to show every stop for the chosen day, or the whole trip.
    private func fit() {
        let points = stops.compactMap(\.coordinate)
        guard !points.isEmpty else {
            if let center = trip.coordinate {
                position = .region(MKCoordinateRegion(center: center, latitudinalMeters: 20_000, longitudinalMeters: 20_000))
            }
            return
        }
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        let center = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.01),
                                    longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.01))
        withAnimation {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
}
