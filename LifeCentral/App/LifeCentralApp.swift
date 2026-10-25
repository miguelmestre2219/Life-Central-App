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
                .environment(BackupService.shared)
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

    /// SwiftData's usual place, spelled out so backups know where to look.
    static let storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")

    /// One SQLite file on the phone. The models are already shaped for iCloud,
    /// so sync can be switched on with `cloudKitDatabase: .automatic` once the
    /// iCloud capability is added to the app.
    @MainActor
    static let container: ModelContainer = {
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        // A restored backup is swapped in before the store opens.
        BackupRestore.applyPendingIfNeeded(storeURL: storeURL)
        let schema = Schema(models)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            Seed.runIfNeeded(container.mainContext)
            return container
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }()
}
