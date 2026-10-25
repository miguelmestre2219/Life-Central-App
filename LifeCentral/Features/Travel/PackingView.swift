import SwiftUI
import SwiftData

struct PackingView: View {
    let trip: Trip

    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate, order: .reverse) private var allTrips: [Trip]
    @State private var newItem = ""
    @State private var newGroup = "Clothes"
    @State private var hidePacked = false
    @FocusState private var isAdding: Bool

    private var color: Color { Color(hex: trip.colorHex) }
    private var items: [PackingItem] { (trip.packing ?? []).sorted { $0.sortOrder < $1.sortOrder } }
    private var otherTrips: [Trip] { allTrips.filter { $0 !== trip && !($0.packing ?? []).isEmpty } }

    /// A sensible starting list, grouped the same way as the screen.
    static let starter: [(group: String, names: [String])] = [
        ("Documents", ["Passport or ID", "Travel insurance", "Bank cards", "Bookings and tickets"]),
        ("Clothes", ["T-shirts", "Trousers or shorts", "Underwear", "Socks", "Pyjamas", "Jacket", "Comfortable shoes"]),
        ("Toiletries", ["Toothbrush", "Toothpaste", "Deodorant", "Sun cream", "Medication"]),
        ("Tech", ["Phone charger", "Plug adapter", "Headphones", "Power bank"]),
        ("Other", ["Sunglasses", "Reusable water bottle", "Day bag"]),
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(trip.packedCount) of \(items.count)").font(.display(28))
                        Text("packed").foregroundStyle(.secondary)
                        Spacer()
                        Text(DateText.countdown(trip.startDate)).font(.footnote).foregroundStyle(.secondary)
                    }
                    ProgressBar(value: items.isEmpty ? 0 : Double(trip.packedCount) / Double(items.count), color: color)
                }
                .padding(.vertical, 4)

                HStack {
                    TextField("Add an item", text: $newItem)
                        .focused($isAdding)
                        .onSubmit(add)
                        .submitLabel(.done)
                    Menu {
                        Picker("Group", selection: $newGroup) {
                            ForEach(PackingItem.groups, id: \.self) { Text($0) }
                        }
                    } label: {
                        Text(newGroup).font(.footnote.weight(.semibold))
                    }
                    Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2) }
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Add item")
                }
                .tint(color)
            }

            if items.isEmpty {
                Section {
                    Button { addStarter() } label: {
                        Label("Start from a suggested list", systemImage: "sparkles")
                    }
                    if !otherTrips.isEmpty {
                        Menu {
                            ForEach(otherTrips) { other in
                                Button(other.name) { copy(from: other) }
                            }
                        } label: {
                            Label("Copy the list from another trip", systemImage: "doc.on.doc")
                        }
                    }
                } footer: {
                    Text("You can edit, add and remove items afterwards.")
                }
                .tint(color)
            }

            ForEach(PackingItem.groups, id: \.self) { group in
                let groupItems = items.filter { $0.group == group && !(hidePacked && $0.isPacked) }
                if !groupItems.isEmpty {
                    Section {
                        ForEach(groupItems) { item in
                            Button {
                                withAnimation { item.isPacked.toggle() }
                            } label: {
                                HStack(spacing: 12) {
                                    CircleTick(isOn: item.isPacked, color: color, size: 24)
                                    Text(item.name)
                                        .strikethrough(item.isPacked)
                                        .foregroundStyle(item.isPacked ? .secondary : .primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(item.isPacked ? .isSelected : [])
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(groupItems[index]) }
                        }
                    } header: {
                        Text("\(group) · \(groupItems.filter(\.isPacked).count)/\(groupItems.count)")
                    }
                }
            }
        }
        .navigationTitle("Packing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Hide packed", isOn: $hidePacked)
                    Button("Unpack everything") { items.forEach { $0.isPacked = false } }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(items.isEmpty)
            }
        }
    }

    private func add() {
        let name = newItem.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        insert(name, group: newGroup)
        newItem = ""
        isAdding = true
    }

    private func insert(_ name: String, group: String) {
        let item = PackingItem(name: name, group: group, sortOrder: (trip.packing?.count ?? 0))
        context.insert(item)
        item.trip = trip
    }

    private func addStarter() {
        for group in Self.starter {
            for name in group.names { insert(name, group: group.group) }
        }
    }

    private func copy(from other: Trip) {
        for item in (other.packing ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            insert(item.name, group: item.group)
        }
    }
}
