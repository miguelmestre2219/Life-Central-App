import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.appLock) private var appLock = false
    @State private var isUnlocked = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            tabStack(.today) { TodayView() }
                .tabItem { Label("Today", systemImage: Area.today.icon) }
                .tag(AppTab.today)
            tabStack(.money) { MoneyView() }
                .tabItem { Label("Money", systemImage: Area.money.icon) }
                .tag(AppTab.money)
            tabStack(.travel) { TripsView() }
                .tabItem { Label("Travel", systemImage: Area.travel.icon) }
                .tag(AppTab.travel)
            tabStack(.fitness) { FitnessView() }
                .tabItem { Label("Fitness", systemImage: Area.fitness.icon) }
                .tag(AppTab.fitness)
            tabStack(.more) { MoreView() }
                .tabItem { Label("More", systemImage: "square.grid.2x2") }
                .tag(AppTab.more)
        }
        .sheet(item: $router.sheet) { sheet in
            SheetHost(route: sheet.route)
        }
        .fullScreenCover(isPresented: $router.isLiveExpanded) {
            if let session = router.liveSession {
                WorkoutLiveView(session: session)
            }
        }
        .overlay {
            if appLock && !isUnlocked {
                LockScreen(isUnlocked: $isUnlocked)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                isUnlocked = false
                Reminders.shared.reschedule(using: context)
            }
        }
        .task {
            RecurringEntries.generate(in: context)
            await ExchangeRates.shared.refreshIfNeeded()
            Reminders.shared.requestPermissionIfNeeded()
        }
    }

    private func tabStack<Content: View>(_ tab: AppTab, @ViewBuilder root: () -> Content) -> some View {
        NavigationStack(path: router.path(tab)) {
            root()
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                }
        }
        .safeAreaInset(edge: .bottom) {
            LiveWorkoutBar()
        }
    }
}

/// Maps each route to its screen.
struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .search: SearchView()
        case .inbox: InboxView()
        case .moneyCategory(let category): CategoryDetailView(category: category)
        case .moneyEntry(let entry): MoneyEntryDetail(entry: entry)
        case .monthlyPlan: MonthlyPlanView()
        case .bills: BillsView()
        case .trip(let trip): TripView(trip: trip)
        case .tripDay(let trip, let day): TripDayView(trip: trip, day: day)
        case .tripMap(let trip, let day): TripMapView(trip: trip, initialDay: day)
        case .tripBudget(let trip): TripBudgetView(trip: trip)
        case .packing(let trip): PackingView(trip: trip)
        case .explore: ExploreView()
        case .workoutTemplate(let template): WorkoutEditorView(template: template)
        case .exerciseGuide(let id): ExerciseGuideView(exerciseID: id)
        case .progress(let id): FitnessProgressView(initialExerciseID: id)
        case .session(let session): SessionDetailView(session: session)
        case .health: HealthView()
        case .healthMetric(let metric): HealthMetricView(metric: metric)
        case .documents: DocumentsView()
        case .documentFolder(let folder): DocumentFolderView(folder: folder)
        case .document(let document): DocumentDetailView(document: document)
        case .habits: HabitsView()
        case .tasks: TasksView()
        case .meals: MealsView()
        case .shopping: ShoppingView()
        case .friends: FriendsView()
        case .settings: SettingsView()
        }
    }
}

/// Maps each sheet to its form.
struct SheetHost: View {
    let route: SheetRoute

    var body: some View {
        switch route {
        case .quickAdd:
            QuickAddSheet()
        case .moneyEntry(let entry, let category, let trip, let isIncome):
            MoneyEntryForm(entry: entry, presetCategory: category, presetTrip: trip, startAsIncome: isIncome)
        case .bill(let bill):
            BillForm(bill: bill)
        case .startWorkout:
            StartWorkoutSheet()
        case .healthLog(let kind):
            HealthLogSheet(kind: kind)
        case .task(let task, let trip):
            TaskForm(task: task, presetTrip: trip)
        case .trip(let trip):
            TripForm(trip: trip)
        case .tripItem(let item, let trip, let day):
            TripItemForm(item: item, presetTrip: trip, presetDay: day)
        case .tripShare(let trip):
            TripShareSheet(trip: trip)
        case .googleMaps(let trip, let day):
            GoogleMapsSheet(trip: trip, day: day)
        case .document(let folder, let trip, let bill, let tripItem):
            DocumentAddSheet(presetFolder: folder, trip: trip, bill: bill, tripItem: tripItem)
        case .meal(let meal, let day):
            MealForm(meal: meal, presetDay: day)
        case .habit(let habit):
            HabitForm(habit: habit)
        case .newWorkout:
            NewWorkoutSheet()
        }
    }
}
