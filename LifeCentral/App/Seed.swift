import Foundation
import SwiftData

/// Starter content on first launch: spending categories and three gym workouts,
/// so no screen starts completely empty. Everything can be edited or deleted.
enum Seed {
    @MainActor
    static func runIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: SettingsKey.didSeedDefaults) else { return }
        UserDefaults.standard.set(true, forKey: SettingsKey.didSeedDefaults)

        let spending: [(String, String, String)] = [
            ("Groceries", "cart", "047857"),
            ("Eating out", "fork.knife", "A16207"),
            ("Transport", "tram", "1D4ED8"),
            ("Home", "house", "334155"),
            ("Shopping", "bag", "BE185D"),
            ("Fun", "sparkles", "7C3AED"),
            ("Health", "cross.case", "BE123C"),
            ("Travel", "airplane", "0E7490"),
            ("Gifts", "gift", "C2410C"),
            ("Other", "ellipsis.circle", "64748B"),
        ]
        for (index, item) in spending.enumerated() {
            context.insert(MoneyCategory(name: item.0, icon: item.1, colorHex: item.2, sortOrder: index))
        }
        context.insert(MoneyCategory(name: "Salary", icon: "banknote", colorHex: "047857", isIncome: true, sortOrder: 100))
        context.insert(MoneyCategory(name: "Other income", icon: "plus.circle", colorHex: "047857", isIncome: true, sortOrder: 101))

        let workouts: [(String, String, [(String, Int, Int, Double, Int)])] = [
            ("Push day", "C2410C", [
                ("bench-press", 4, 8, 40, 120), ("overhead-press", 3, 10, 25, 90),
                ("incline-dumbbell-press", 3, 10, 14, 90), ("lateral-raise", 3, 15, 6, 60),
                ("tricep-pushdown", 3, 12, 20, 60),
            ]),
            ("Pull day", "1D4ED8", [
                ("lat-pulldown", 4, 10, 40, 90), ("barbell-row", 3, 8, 40, 120),
                ("seated-cable-row", 3, 10, 35, 90), ("face-pull", 3, 15, 15, 60),
                ("bicep-curl", 3, 12, 10, 60),
            ]),
            ("Leg day", "047857", [
                ("squat", 4, 8, 50, 150), ("romanian-deadlift", 3, 10, 40, 120),
                ("leg-press", 3, 12, 80, 90), ("walking-lunge", 3, 12, 10, 90),
                ("calf-raise", 3, 15, 30, 60),
            ]),
        ]
        for (order, workout) in workouts.enumerated() {
            let template = WorkoutTemplate(name: workout.0, colorHex: workout.1)
            template.sortOrder = order
            context.insert(template)
            for (index, ex) in workout.2.enumerated() {
                let name = ExerciseLibrary.exercise(ex.0)?.name ?? ex.0
                let item = TemplateExercise(exerciseID: ex.0, name: name, sets: ex.1, reps: ex.2, weightKg: ex.3, restSeconds: ex.4, sortOrder: index)
                context.insert(item)
                item.template = template
            }
        }

        let water = Habit(name: "Drink 2 L of water", icon: "drop", detail: "Fills in from water you log")
        water.linkedMetric = "water"
        context.insert(water)

        try? context.save()
    }
}
