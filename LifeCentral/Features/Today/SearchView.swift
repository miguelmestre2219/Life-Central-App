import SwiftUI
import SwiftData

/// Searches every area at once. Data sets are small, so filtering in memory
/// keeps this simple and instant.
struct SearchView: View {
    @Environment(AppRouter.self) private var router
    @State private var query = ""

    @Query private var entries: [MoneyEntry]
    @Query private var bills: [Bill]
    @Query private var trips: [Trip]
    @Query private var tripItems: [TripItem]
    @Query private var templates: [WorkoutTemplate]
    @Query private var documents: [Document]
    @Query private var tasks: [TodoItem]
    @Query private var meals: [MealPlanEntry]

    private struct Hit: Identifiable {
        let id: String
        let title: String
        let detail: String
        let route: Route
    }

    private struct HitGroup: Identifiable {
        let id: String
        let area: Area
        let hits: [Hit]
    }

    private func matches(_ texts: String...) -> Bool {
        texts.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private var groups: [HitGroup] {
        guard query.count >= 2 else { return [] }
        var result: [HitGroup] = []
        let money = entries.filter { matches($0.note, $0.category?.name ?? "", $0.paidWith) }
            .sorted { $0.date > $1.date }.prefix(8)
            .map { Hit(id: "e\($0.persistentModelID.hashValue)", title: $0.title,
                       detail: "\(MoneyFormat.string($0.amountMinor, $0.currencyCode)) · \(DateText.relativeDay($0.date))", route: .moneyEntry($0)) }
        let billHits = bills.filter { matches($0.name, $0.group, $0.notes) }
            .map { Hit(id: "b\($0.persistentModelID.hashValue)", title: $0.name, detail: "Bill · \($0.group)", route: .bills) }
        if !(money.isEmpty && billHits.isEmpty) { result.append(HitGroup(id: "money", area: .money, hits: Array(money) + billHits)) }

        var travel = trips.filter { matches($0.name, $0.destination, $0.notes, $0.otherCitiesText) }
            .map { Hit(id: "t\($0.persistentModelID.hashValue)", title: $0.name, detail: DateText.range($0.startDate, $0.endDate), route: .trip($0)) }
        travel += tripItems.filter { matches($0.title, $0.placeName, $0.notes) }.prefix(8).compactMap { item in
            guard let trip = item.trip else { return nil }
            return Hit(id: "i\(item.persistentModelID.hashValue)", title: item.title,
                       detail: "\(trip.name) · \(DateText.relativeDay(item.day))", route: .tripDay(trip, item.day))
        }
        if !travel.isEmpty { result.append(HitGroup(id: "travel", area: .travel, hits: travel)) }

        let workouts = templates.filter { t in matches(t.name) || t.orderedExercises.contains { matches($0.name) } }
            .map { Hit(id: "w\($0.persistentModelID.hashValue)", title: $0.name, detail: "\($0.orderedExercises.count) exercises", route: .workoutTemplate($0)) }
        let exercises = ExerciseLibrary.all.filter { matches($0.name) }.prefix(5)
            .map { Hit(id: "x\($0.id)", title: $0.name, detail: "How to do it", route: .exerciseGuide($0.id)) }
        if !(workouts.isEmpty && exercises.isEmpty) { result.append(HitGroup(id: "fitness", area: .fitness, hits: workouts + exercises)) }

        let docs = documents.filter { matches($0.title, $0.folder, $0.notes, $0.recognizedText) }
            .map { Hit(id: "d\($0.persistentModelID.hashValue)", title: $0.title, detail: $0.folder, route: .document($0)) }
        if !docs.isEmpty { result.append(HitGroup(id: "docs", area: .documents, hits: docs)) }

        let todo = tasks.filter { matches($0.title, $0.notes) }
            .map { Hit(id: "k\($0.persistentModelID.hashValue)", title: $0.title,
                       detail: $0.dueDate.map { "Due \(DateText.relativeDay($0))" } ?? "Task", route: .tasks) }
        if !todo.isEmpty { result.append(HitGroup(id: "tasks", area: .tasks, hits: todo)) }

        let food = meals.filter { matches($0.name, $0.ingredients) }.prefix(5)
            .map { Hit(id: "m\($0.persistentModelID.hashValue)", title: $0.name, detail: DateText.relativeDay($0.day), route: .meals) }
        if !food.isEmpty { result.append(HitGroup(id: "meals", area: .meals, hits: Array(food))) }
        return result
    }

    var body: some View {
        List {
            if query.count < 2 {
                Text("Search spending, bills, trips, places, workouts, exercises, documents (even words inside scans), tasks and meals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if groups.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.hits) { hit in
                        Button { router.show(hit.route) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(hit.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.area.title).foregroundStyle(group.area.color)
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search everything")
    }
}
