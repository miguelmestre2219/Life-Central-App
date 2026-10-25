import Foundation
import SwiftData

enum WorkoutKind: String, CaseIterable, Identifiable {
    case strength, cardio, mobility
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// A reusable workout in the library ("Push day"). Not tied to a date:
/// you pick one on the day and start it.
@Model
final class WorkoutTemplate {
    var name: String = ""
    var colorHex: String = "C2410C"
    var kindRaw: String = WorkoutKind.strength.rawValue
    var notes: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    /// Set when this workout came from a friend.
    var sharedBy: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.template)
    var sessions: [WorkoutSession]? = []

    init(name: String, colorHex: String = "C2410C", kind: WorkoutKind = .strength) {
        self.name = name
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
    }

    var kind: WorkoutKind {
        get { WorkoutKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    var orderedExercises: [TemplateExercise] {
        (exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var lastSession: WorkoutSession? {
        (sessions ?? []).filter { $0.endedAt != nil }.max { $0.startedAt < $1.startedAt }
    }

    /// Rough length: sets × (45 s of work + rest).
    var estimatedMinutes: Int {
        let seconds = orderedExercises.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) }
        return max(10, Int((Double(seconds) / 60).rounded()))
    }
}

@Model
final class TemplateExercise {
    /// Id from the built-in exercise list, or "custom-<uuid>".
    var exerciseID: String = ""
    var name: String = ""
    var sets: Int = 3
    var reps: Int = 10
    var weightKg: Double = 0
    /// For timed or distance exercises (plank seconds, run minutes).
    var durationSeconds: Int = 0
    var restSeconds: Int = 90
    var sortOrder: Int = 0
    var template: WorkoutTemplate?

    init(exerciseID: String, name: String, sets: Int = 3, reps: Int = 10, weightKg: Double = 0, restSeconds: Int = 90, sortOrder: Int = 0) {
        self.exerciseID = exerciseID
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.restSeconds = restSeconds
        self.sortOrder = sortOrder
    }

    var planText: String {
        if durationSeconds > 0 {
            return "\(sets) × \(DateText.clock(seconds: durationSeconds))"
        }
        let weight = weightKg > 0 ? " · \(WeightText.kg(weightKg))" : " · body weight"
        let rest = restSeconds >= 60 ? "\(restSeconds / 60) min" : "\(restSeconds) s"
        return "\(sets) × \(reps)\(weight) · rest \(rest)"
    }
}

/// One visit to the gym (or run), started from a template.
@Model
final class WorkoutSession {
    var startedAt: Date = Date.now
    var endedAt: Date?
    var name: String = ""
    var colorHex: String = "C2410C"
    /// 1 Easy … 5 Max, 0 when not rated.
    var feeling: Int = 0
    var note: String = ""
    var savedToHealth: Bool = false
    /// Index into the exercise order the person is on, for resuming.
    var currentExerciseIndex: Int = 0

    var template: WorkoutTemplate?
    @Relationship(deleteRule: .cascade, inverse: \SessionSet.session)
    var sets: [SessionSet]? = []

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }

    var isFinished: Bool { endedAt != nil }

    var durationMinutes: Int {
        Int(((endedAt ?? .now).timeIntervalSince(startedAt) / 60).rounded())
    }

    var orderedSets: [SessionSet] {
        (sets ?? []).sorted { ($0.exerciseOrder, $0.setIndex) < ($1.exerciseOrder, $1.setIndex) }
    }

    /// Exercises in order, each with its sets.
    var exerciseGroups: [(order: Int, id: String, name: String, sets: [SessionSet])] {
        let grouped = Dictionary(grouping: orderedSets, by: \.exerciseOrder)
        return grouped.keys.sorted().compactMap { order in
            guard let sets = grouped[order], let first = sets.first else { return nil }
            return (order: order, id: first.exerciseID, name: first.exerciseName, sets: sets)
        }
    }

    var doneSets: [SessionSet] { (sets ?? []).filter(\.isDone) }

    var volumeKg: Double {
        doneSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    static let feelings = ["Easy", "OK", "Good", "Hard", "Max"]
}

@Model
final class SessionSet {
    var exerciseID: String = ""
    var exerciseName: String = ""
    var exerciseOrder: Int = 0
    var setIndex: Int = 0
    var weightKg: Double = 0
    var reps: Int = 0
    var durationSeconds: Int = 0
    var restSeconds: Int = 90
    var isDone: Bool = false
    var completedAt: Date?
    var session: WorkoutSession?

    init(exerciseID: String, exerciseName: String, exerciseOrder: Int, setIndex: Int, weightKg: Double, reps: Int, restSeconds: Int) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.exerciseOrder = exerciseOrder
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.restSeconds = restSeconds
    }

    /// Estimated one-rep max (Epley), for comparing sets of different reps.
    var estimatedMax: Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        return weightKg * (1 + Double(reps) / 30)
    }
}

/// An exercise someone added that is not in the built-in list.
@Model
final class CustomExercise {
    var exerciseID: String = ""
    var name: String = ""
    var muscleRaw: String = "chest"
    var equipment: String = ""
    var steps: String = ""

    init(name: String, muscle: String, equipment: String) {
        self.exerciseID = "custom-" + UUID().uuidString
        self.name = name
        self.muscleRaw = muscle
        self.equipment = equipment
    }
}

enum WeightText {
    static func kg(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + " kg"
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
