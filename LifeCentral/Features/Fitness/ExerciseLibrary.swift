import Foundation

enum Muscle: String, CaseIterable, Identifiable {
    case chest, back, shoulders, arms, legs, glutes, core, cardio, mobility
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Equipment: String, CaseIterable, Identifiable {
    case barbell, dumbbells, kettlebell, cable, machine, bodyWeight, cardioMachine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbells: "Dumbbells"
        case .kettlebell: "Kettlebell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bodyWeight: "Body weight"
        case .cardioMachine: "Cardio machine"
        }
    }
}

/// One exercise in the built-in list, with its how-to and its cartoon.
struct Exercise: Identifiable, Hashable {
    struct Plan {
        let sets: Int
        let reps: Int
        /// For timed exercises (plank, running).
        let seconds: Int
        let rest: Int
    }

    let id: String
    let name: String
    let muscle: Muscle
    let alsoWorks: [Muscle]
    let equipment: Equipment
    let isTimed: Bool
    let plan: Plan
    let steps: [String]
    let mistakes: [String]
    let tip: String
    let motion: Motion

    static func == (a: Exercise, b: Exercise) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var musclesText: String {
        ([muscle] + alsoWorks).map(\.title).joined(separator: ", ")
    }
}

enum ExerciseLibrary {
    private static let byID: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func exercise(_ id: String) -> Exercise? { byID[id] }

    static func exercises(for muscle: Muscle) -> [Exercise] {
        all.filter { $0.muscle == muscle }
    }

    /// Builds the plan line for a new exercise in a workout.
    static func templateExercise(for exercise: Exercise, sortOrder: Int) -> TemplateExercise {
        let item = TemplateExercise(exerciseID: exercise.id, name: exercise.name, sets: exercise.plan.sets,
                                    reps: exercise.plan.reps, restSeconds: exercise.plan.rest, sortOrder: sortOrder)
        item.durationSeconds = exercise.plan.seconds
        return item
    }
}
