import SwiftUI
import SwiftData

/// The + button. Each tile opens the same form as that area's own add button,
/// so what you add here lands in the same place and shows up in the same lists.
struct QuickAddSheet: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \MoneyEntry.createdAt, order: .reverse) private var recentEntries: [MoneyEntry]
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    private struct Option: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let area: Area
        let action: (AppRouter, Trip?) -> Void
    }

    private let options: [Option] = [
        Option(id: "money", title: "Spend or income", symbol: "creditcard", area: .money) { r, _ in r.present(.moneyEntry(nil)) },
        Option(id: "bill", title: "Bill", symbol: "clock.arrow.circlepath", area: .money) { r, _ in r.present(.bill(nil)) },
        Option(id: "workout", title: "Start workout", symbol: "dumbbell", area: .fitness) { r, _ in r.present(.startWorkout) },
        Option(id: "health", title: "Log health", symbol: "heart", area: .health) { r, _ in r.present(.healthLog(.water)) },
        Option(id: "task", title: "Task", symbol: "calendar", area: .tasks) { r, _ in r.present(.task(nil)) },
        Option(id: "habit", title: "Habit check-in", symbol: "checkmark.circle", area: .habits) { r, _ in
            r.sheet = nil
            r.show(.habits)
        },
        Option(id: "trip", title: "Trip plan item", symbol: "airplane", area: .travel) { r, trip in
            if let trip { r.present(.tripItem(nil, trip: trip, day: nil)) } else { r.present(.trip(nil)) }
        },
        Option(id: "doc", title: "Document", symbol: "doc.text", area: .documents) { r, _ in r.present(.document(folder: nil)) },
        Option(id: "meal", title: "Meal", symbol: "fork.knife", area: .meals) { r, _ in r.present(.meal(nil, day: .now)) },
    ]

    /// Up to three categories used most recently, for one-tap repeats.
    private var frequentCategories: [MoneyCategory] {
        var seen: [MoneyCategory] = []
        for entry in recentEntries.prefix(30) {
            if let category = entry.category, !seen.contains(category) { seen.append(category) }
            if seen.count == 3 { break }
        }
        return seen
    }

    private var nextTrip: Trip? { trips.first { !$0.isPast } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !frequentCategories.isEmpty {
                        SectionLabel(text: "Again?")
                        HStack(spacing: 8) {
                            ForEach(frequentCategories) { category in
                                Button(category.name) { router.present(.moneyEntry(nil, category: category)) }
                                    .font(.subheadline)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Theme.card, in: Capsule())
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(options) { option in
                            Button { option.action(router, nextTrip) } label: {
                                VStack(spacing: 8) {
                                    IconChip(symbol: option.symbol, color: option.area.color)
                                    Text(option.title)
                                        .font(.footnote.weight(.semibold))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .padding(.horizontal, 4)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Each option opens the same form as that area's own add button.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.sheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
