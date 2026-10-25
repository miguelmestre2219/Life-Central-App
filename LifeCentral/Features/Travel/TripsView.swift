import SwiftUI
import SwiftData

struct TripsView: View {
    enum Filter: String, CaseIterable { case upcoming = "Upcoming", ideas = "Ideas", past = "Past" }

    @Environment(AppRouter.self) private var router
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var filter: Filter = .upcoming

    private var shown: [Trip] {
        switch filter {
        case .upcoming: trips.filter { !$0.isPast && $0.status == .booked }
        case .ideas: trips.filter { !$0.isPast && $0.status == .idea }
        case .past: Array(trips.filter(\.isPast).reversed())
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                if shown.isEmpty {
                    EmptyState(symbol: "airplane", title: filter == .past ? "No past trips" : "No trips here yet",
                               message: "Plan a trip day by day and hour by hour, with maps, a budget in any currency and a packing list.",
                               actionTitle: "Plan a trip", color: Area.travel.color) { router.present(.trip(nil)) }
                        .card()
                }
                ForEach(shown) { trip in
                    NavigationLink(value: Route.trip(trip)) { TripCard(trip: trip) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Travel")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.explore) { Image(systemName: "globe") }
                    .accessibilityLabel("Explore countries")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.trip(nil)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New trip")
            }
        }
    }
}

struct TripCard: View {
    let trip: Trip
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    var body: some View {
        let color = Color(hex: trip.colorHex)
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.name).font(.system(size: 22, weight: .heavy, design: .rounded))
                    Text("\(DateText.range(trip.startDate, trip.endDate)) · \(trip.dayCount) days")
                        .font(.footnote).opacity(0.9)
                }
                Spacer()
                Text(trip.isUnderway ? "now" : (trip.isPast ? "done" : DateText.countdown(trip.startDate)))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.white, in: Capsule())
                    .foregroundStyle(color)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .bottomLeading)
            .background(color)

            HStack {
                Text(stats).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if !trip.countryCode.isEmpty { Text(Country.flag(trip.countryCode)) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var stats: String {
        var parts = ["Planned \(trip.plannedDayCount)/\(trip.dayCount)"]
        if trip.budgetMinor > 0 {
            parts.append("\(MoneyFormat.string(trip.spentHomeMinor, home, whole: true)) of \(MoneyFormat.string(trip.budgetMinor, home, whole: true))")
        }
        if let packing = trip.packing, !packing.isEmpty {
            parts.append("\(trip.packedCount)/\(packing.count) packed")
        }
        return parts.joined(separator: " · ")
    }
}
