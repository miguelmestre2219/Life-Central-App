import SwiftUI
import SwiftData

struct MoreView: View {
    @Query private var documents: [Document]
    @Query(filter: #Predicate<Habit> { !$0.isArchived }) private var habits: [Habit]
    @Query(filter: #Predicate<TodoItem> { !$0.isDone }) private var tasks: [TodoItem]
    @Query private var meals: [MealPlanEntry]
    @Query(filter: #Predicate<ShoppingItem> { !$0.isBought }) private var shopping: [ShoppingItem]
    @Query private var friends: [Friend]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(.documents, route: .documents, detail: documentsText)
                tile(.habits, route: .habits, detail: habitsText)
                tile(.tasks, route: .tasks, detail: tasksText)
                tile(.meals, route: .meals, detail: mealsText, title: "Meals")
                tileView(title: "Shopping", symbol: "cart", color: Area.meals.color, route: .shopping,
                         detail: shopping.isEmpty ? "List is empty" : "\(shopping.count) to buy")
                tile(.health, route: .health, detail: "Apple Health and logs")
                tile(.friends, route: .friends, detail: friends.isEmpty ? "Share trips and workouts" : "\(friends.count) people", title: "Friends")
                tile(.settings, route: .settings, detail: "Currency, Face ID, backup")
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("More")
    }

    private func tile(_ area: Area, route: Route, detail: String, title: String? = nil) -> some View {
        tileView(title: title ?? area.title, symbol: area.icon, color: area.color, route: route, detail: detail)
    }

    private func tileView(title: String, symbol: String, color: Color, route: Route, detail: String) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 10) {
                IconChip(symbol: symbol, color: color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .card()
        }
        .buttonStyle(.plain)
    }

    private var documentsText: String {
        let expiring = documents.filter(\.isExpiringSoon).count
        if expiring > 0 { return "\(expiring) expiring soon" }
        return documents.isEmpty ? "Scan your first one" : "\(documents.count) stored"
    }

    private var habitsText: String {
        guard !habits.isEmpty else { return "Build a streak" }
        return "\(habits.filter { $0.isDone(on: .now) }.count) of \(habits.count) today"
    }

    private var tasksText: String {
        let today = tasks.filter { $0.isDueToday || $0.isOverdue }.count
        return today > 0 ? "\(today) for today" : (tasks.isEmpty ? "All clear" : "\(tasks.count) open")
    }

    private var mealsText: String {
        let start = Date.now.startOfWeek
        let planned = meals.filter { $0.day >= start && $0.day < start.adding(days: 7) }.count
        return planned == 0 ? "Plan the week" : "\(planned) planned this week"
    }
}

struct FriendsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]
    @State private var showAdd = false
    @State private var newName = ""

    private let color = Area.friends.color

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    IconChip(symbol: "person.2.fill", color: color, size: 44)
                    Text("Plan together over iCloud").font(.headline)
                    Text("Invite friends with an iPhone to a trip, a workout or the shopping list. Everyone sees changes as they happen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label("Live sharing turns on once the app is set up with your Apple developer account.", systemImage: "clock")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("People") {
                ForEach(friends) { friend in
                    HStack(spacing: 12) {
                        Text(friend.initial)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color(hex: friend.colorHex), in: Circle())
                        Text(friend.name)
                    }
                }
                .onDelete { offsets in for i in offsets { context.delete(friends[i]) } }
                Button { showAdd = true } label: { Label("Add someone", systemImage: "plus") }
            }

            Section {
                ForEach(trips.filter { !$0.isPast }) { trip in
                    Button { router.present(.tripShare(trip)) } label: { Label(trip.name, systemImage: "airplane") }
                }
                ForEach(templates) { template in
                    ShareLink(item: workoutText(template)) { Label(template.name, systemImage: "dumbbell") }
                }
                NavigationLink(value: Route.shopping) { Label("Shopping list", systemImage: "cart") }
            } header: {
                Text("Send a copy now")
            } footer: {
                Text("A copy is a snapshot; it won't update.")
            }
        }
        .tint(color)
        .navigationTitle("Friends")
        .alert("Add someone", isPresented: $showAdd) {
            TextField("Name", text: $newName)
            Button("Add") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    context.insert(Friend(name: name, colorHex: Color.palette[friends.count % Color.palette.count]))
                }
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        }
    }

    private func workoutText(_ template: WorkoutTemplate) -> String {
        ([template.name] + template.orderedExercises.map { "• \($0.name): \($0.planText)" }).joined(separator: "\n")
    }
}
