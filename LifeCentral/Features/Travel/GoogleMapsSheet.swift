import SwiftUI

/// Sends a day, a place or the whole trip to Google Maps. Nothing comes back:
/// it is a copy, so the plan here stays the one to edit.
struct GoogleMapsSheet: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var day: Date
    @State private var mode: GoogleMapsLink.Mode = .transit
    @State private var kmlURL: URL?

    init(trip: Trip, day: Date?) {
        self.trip = trip
        let start = trip.isUnderway ? Date.now.startOfDay : trip.startDate.startOfDay
        _day = State(initialValue: day?.startOfDay ?? start)
    }

    private var color: Color { Color(hex: trip.colorHex) }
    private var stops: [TripItem] { trip.items(on: day).filter { $0.hasLocation || !$0.placeName.isEmpty } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day", selection: $day) {
                        ForEach(Array(trip.days.enumerated()), id: \.offset) { index, date in
                            Text("Day \(index + 1) · \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))").tag(date)
                        }
                    }
                    Picker("Getting around", selection: $mode) {
                        ForEach(GoogleMapsLink.Mode.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if stops.count >= 2 {
                        Text(stops.map(\.title).joined(separator: " → "))
                            .font(.footnote).foregroundStyle(.secondary)
                        Button {
                            if let url = GoogleMapsLink.directions(stops, mode: mode) { openURL(url) }
                        } label: {
                            Label("Open the day's route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .fontWeight(.semibold)
                        }
                        if stops.count > GoogleMapsLink.maxWaypoints + 2 {
                            Text("Google Maps takes up to 11 stops, so the last few are left off.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    } else {
                        Text("Add at least two places to this day to get directions between them.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Directions for one day")
                } footer: {
                    Text("Stops go in the order of your plan. On iPhone, Google Maps may show only the first few stops in between.")
                }

                if !stops.isEmpty {
                    Section("One place") {
                        ForEach(stops) { item in
                            Button {
                                if let url = GoogleMapsLink.place(item) { openURL(url) }
                            } label: {
                                HStack {
                                    Label(item.title, systemImage: item.kind.icon).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    if let kmlURL {
                        ShareLink(item: kmlURL) {
                            Label("Export the whole trip (KML file)", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Text("Add places with a map pin to export the trip.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Whole trip")
                } footer: {
                    Text("Save the file, then open Google My Maps (mymaps.google.com), create a map and import it. Each day becomes its own layer, and the map appears in the Google Maps app under Saved, Maps.")
                }

                Section {
                    Label("This sends a copy. Changes made in Google Maps don't come back to Life Central.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(color)
            .navigationTitle("Google Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear {
                kmlURL = trip.mappedItems().isEmpty ? nil : TripExport.kmlFile(for: trip)
            }
        }
    }
}
