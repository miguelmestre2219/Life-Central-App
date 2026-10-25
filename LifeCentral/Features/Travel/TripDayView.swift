import SwiftUI
import SwiftData

struct TripDayView: View {
    let trip: Trip

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"
    @State private var day: Date

    init(trip: Trip, day: Date) {
        self.trip = trip
        _day = State(initialValue: day.startOfDay)
    }

    private var color: Color { Color(hex: trip.colorHex) }
    private var items: [TripItem] { trip.items(on: day) }
    private var dayCostHome: Int { items.reduce(0) { $0 + $1.costHomeMinor } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dayChips
                summary
                if items.isEmpty {
                    EmptyState(symbol: "calendar.badge.plus", title: "Nothing planned for this day",
                               message: "Add sights, meals, travel and where you're staying, hour by hour.",
                               actionTitle: "Add to this day", color: color) { add() }
                        .card()
                        .padding(.horizontal, Theme.gutter)
                } else {
                    timeline
                }
            }
            .padding(.bottom, 90)
        }
        .screenBackground()
        .overlay(alignment: .bottom) {
            if !items.isEmpty {
                FloatingAddButton(title: "Add to day", color: color, action: add)
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle("Day \(trip.dayNumber(day))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { router.push(.tripMap(trip, day)) } label: { Label("Map of this day", systemImage: "map") }
                    Button { router.present(.googleMaps(trip, day)) } label: { Label("Directions in Google Maps", systemImage: "arrow.up.right.square") }
                } label: {
                    Image(systemName: "map")
                }
                .accessibilityLabel("Maps")
            }
        }
    }

    private var dayChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(trip.days.enumerated()), id: \.offset) { index, date in
                        let isOn = date.isSameDay(as: day)
                        Button { day = date } label: {
                            VStack(spacing: 2) {
                                Text("Day \(index + 1)").font(.caption.weight(.bold))
                                Text(date.formatted(.dateTime.weekday(.abbreviated).day())).font(.caption2)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(isOn ? .white : .primary)
                            .background(isOn ? color : Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
            .onAppear { proxy.scrollTo(trip.dayNumber(day) - 1, anchor: .center) }
        }
    }

    private var summary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.headline)
                Text("\(items.count) plan\(items.count == 1 ? "" : "s")\(dayCostHome > 0 ? " · about \(MoneyFormat.string(dayCostHome, home, whole: true))" : "")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if trip.mappedItems(on: day).count >= 1 {
                Button { router.present(.googleMaps(trip, day)) } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(color)
            }
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                Button { router.present(.tripItem(item, trip: trip, day: day)) } label: {
                    TripItemRow(item: item, color: color, home: home)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if item.booking != .none {
                        Button(item.booking == .booked ? "Mark as to book" : "Mark as booked") {
                            item.booking = item.booking == .booked ? .toBook : .booked
                        }
                    }
                    if item.costMinor > 0 && !item.isPaid {
                        Button("Add cost to Money") { item.recordPayment(in: context) }
                    }
                    if let url = GoogleMapsLink.place(item), item.hasLocation || !item.placeName.isEmpty {
                        Link(destination: url) { Label("Open in Google Maps", systemImage: "arrow.up.right.square") }
                    }
                    Button("Delete", role: .destructive) { context.delete(item) }
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
    }

    private func add() {
        router.present(.tripItem(nil, trip: trip, day: day))
    }
}

struct TripItemRow: View {
    let item: TripItem
    let color: Color
    let home: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Text(item.startTime.map(DateText.time) ?? "Any")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.top, 14)

            VStack(spacing: 0) {
                Circle().fill(color).frame(width: 10, height: 10).padding(.top, 18)
                Rectangle().fill(color.opacity(0.25)).frame(width: 2)
            }

            HStack(alignment: .top, spacing: 10) {
                IconChip(symbol: item.kind.icon, color: color, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if !item.placeName.isEmpty && item.placeName != item.title {
                        Label(item.placeName, systemImage: "mappin").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        if item.startTime != nil {
                            Text(DateText.duration(minutes: item.durationMinutes))
                        }
                        if item.costMinor > 0 {
                            Text(MoneyFormat.string(item.costMinor, item.costCurrency))
                            if item.isPaid { Image(systemName: "checkmark.circle.fill").foregroundStyle(Area.money.color) }
                        }
                        if item.booking == .toBook {
                            Text("To book").foregroundStyle(.orange).fontWeight(.semibold)
                        } else if item.booking == .booked {
                            Text("Booked").foregroundStyle(Area.money.color)
                        }
                        if !(item.documents ?? []).isEmpty {
                            Image(systemName: "paperclip")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.vertical, 4)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
