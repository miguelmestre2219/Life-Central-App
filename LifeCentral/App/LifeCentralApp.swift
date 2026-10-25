import SwiftUI
import SwiftData

@main
struct LifeCentralApp: App {
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(ExchangeRates.shared)
                .environment(HealthService.shared)
        }
        .modelContainer(AppSchema.container)
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        MoneyCategory.self, PlanOverride.self, MoneyEntry.self, Bill.self,
        Trip.self, TripItem.self, PackingItem.self, SavedPlace.self, VisitedCountry.self,
        WorkoutTemplate.self, TemplateExercise.self, WorkoutSession.self, SessionSet.self, CustomExercise.self,
        Document.self, Habit.self, TodoItem.self, MealPlanEntry.self, Recipe.self, ShoppingItem.self,
        HealthLog.self, Friend.self,
    ]

    /// One SQLite file on the phone. The models are already shaped for iCloud,
    /// so sync can be switched on with `cloudKitDatabase: .automatic` once the
    /// iCloud capability is added to the app.
    @MainActor
    static let container: ModelContainer = {
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            Seed.runIfNeeded(container.mainContext)
            return container
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }()
}
