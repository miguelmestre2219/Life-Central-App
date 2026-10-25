import SwiftUI
import SwiftData

struct TripView: View {
    let trip: Trip

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    private var color: Color { Color(hex: trip.colorHex) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                actions
                days
                tiles
                bookings
                tasks
            }
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { router.present(.trip(trip)) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if !trip.countryCode.isEmpty { Text(Country.flag(trip.countryCode)).font(.title2) }
                Text(trip.status == .idea ? "IDEA" : (trip.isUnderway ? "ON THE TRIP" : (trip.isPast ? "DONE" : DateText.countdown(trip.startDate).uppercased())))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.white.opacity(0.22), in: Capsule())
            }
            Text(trip.name).font(.display(32))
            Text("\(DateText.range(trip.startDate, trip.endDate)) · \(trip.dayCount) days")
                .font(.subheadline).opacity(0.9)
            if !trip.otherCities.isEmpty {
                Text(([trip.destination] + trip.otherCities).joined(separator: " → "))
                    .font(.footnote).opacity(0.9)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, Theme.gutter)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionButton("Map", symbol: "map") { router.push(.tripMap(trip, nil)) }
            actionButton("Google Maps", symbol: "arrow.up.right.square") { router.present(.googleMaps(trip, nil)) }
            actionButton("Share", symbol: "person.2") { router.present(.tripShare(trip)) }
        }
        .padding(.horizontal, Theme.gutter)
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var days: some View {
        VStack(spacing: 8) {
            SectionLabel(text: "Day by day")
            VStack(spacing: 0) {
                ForEach(Array(trip.days.enumerated()), id: \.offset) { index, day in
                    NavigationLink(value: Route.tripDay(trip, day)) {
                        DayRow(number: index + 1, day: day, items: trip.items(on: day), color: color)
                    }
                    .buttonStyle(.plain)
                    if index < trip.dayCount - 1 { Divider().padding(.leading, 64) }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            NavigationLink(value: Route.tripBudget(trip)) {
                Tile(symbol: "creditcard", title: "Budget", value: budgetText, color: Area.money.color)
            }
            NavigationLink(value: Route.packing(trip)) {
                let total = trip.packing?.count ?? 0
                Tile(symbol: "suitcase", title: "Packing", value: total == 0 ? "Start a list" : "\(trip.packedCount) of \(total) packed", color: color)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.gutter)
    }

    private var budgetText: String {
        if trip.budgetMinor > 0 {
            return "\(MoneyFormat.string(trip.spentHomeMinor, home, whole: true)) of \(MoneyFormat.string(trip.budgetMinor, home, whole: true))"
        }
        return trip.spentHomeMinor > 0 ? "\(MoneyFormat.string(trip.spentHomeMinor, home, whole: true)) spent" : "Set a budget"
    }

    private var bookings: some View {
        VStack(spacing: 8) {
            SectionLabel(text: "Tickets and bookings")
            VStack(alignment: .leading, spacing: 0) {
                let docs = (trip.documents ?? []).sorted { $0.createdAt > $1.createdAt }
                ForEach(docs) { doc in
                    NavigationLink(value: Route.document(doc)) {
                        HStack(spacing: 12) {
                            IconChip(symbol: "doc.text", color: Area.documents.color, size: 34)
                            VStack(alignment: .leading) {
                                Text(doc.title).foregroundStyle(.primary)
                                Text(doc.tripItem?.title ?? doc.kindLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
                let toBook = (trip.items ?? []).filter { $0.booking == .toBook }
                if !toBook.isEmpty {
                    Text("\(toBook.count) still to book: \(toBook.prefix(3).map(\.title).joined(separator: ", "))")
                        .font(.footnote).foregroundStyle(.orange)
                        .padding(.vertical, 8)
                    Divider()
                }
                Button {
                    router.present(.document(folder: "Travel", trip: trip))
                } label: {
                    Label("Add a ticket or booking", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                }
                .tint(color)
            }
            .card(padding: 14)
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var tasks: some View {
        VStack(spacing: 8) {
            SectionLabel(text: "Before you go")
            VStack(alignment: .leading, spacing: 0) {
                let list = (trip.tasks ?? []).sorted { !$0.isDone && $1.isDone }
                ForEach(list) { task in
                    HStack(spacing: 12) {
                        Button {
                            task.isDone.toggle()
                            task.doneAt = task.isDone ? .now : nil
                        } label: { CircleTick(isOn: task.isDone, color: Area.tasks.color, size: 24) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")
                        Button { router.present(.task(task, trip: trip)) } label: {
                            Text(task.title)
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
                Button { router.present(.task(nil, trip: trip)) } label: {
                    Label("Add a to-do", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 10)
                }
                .tint(color)
            }
            .card(padding: 14)
        }
        .padding(.horizontal, Theme.gutter)
    }
}

private struct DayRow: View {
    let number: Int
    let day: Date
    let items: [TripItem]
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("DAY").font(.system(size: 9, weight: .bold))
                Text("\(number)").font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(items.isEmpty ? .secondary : color)
            .frame(width: 40, height: 40)
            .background((items.isEmpty ? Color.secondary : color).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(items.isEmpty ? "Nothing planned yet" : items.prefix(3).map(\.title).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if day.isToday {
                Text("Today").font(.caption2.weight(.bold)).foregroundStyle(color)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct Tile: View {
    let symbol: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconChip(symbol: symbol, color: color, size: 34)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .card()
    }
}
