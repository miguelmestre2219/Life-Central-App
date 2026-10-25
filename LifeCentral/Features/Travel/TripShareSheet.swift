import SwiftUI

/// Sharing a trip with friends. Live planning together will run over iCloud
/// sharing; until that is switched on, this sends a copy.
struct TripShareSheet: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @State private var kmlURL: URL?

    private var color: Color { Color(hex: trip.colorHex) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        IconChip(symbol: "person.2.fill", color: color, size: 44)
                        Text("Plan \(trip.name) together").font(.headline)
                        Text("Friends you invite through iCloud see the same days, places and packing list, and their changes show up here too. Everyone needs an iPhone signed in to iCloud.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    Label("Live sharing turns on once the app is set up with your Apple developer account.", systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ShareLink(item: TripExport.itinerary(for: trip), subject: Text(trip.name)) {
                        Label("Send the day-by-day plan", systemImage: "text.alignleft")
                    }
                    if let kmlURL {
                        ShareLink(item: kmlURL) {
                            Label("Send the map file (KML)", systemImage: "map")
                        }
                    }
                } header: {
                    Text("Send a copy now")
                } footer: {
                    Text("A copy doesn't update. Friends can open the map file in Google My Maps.")
                }
            }
            .tint(color)
            .navigationTitle("Share trip")
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
