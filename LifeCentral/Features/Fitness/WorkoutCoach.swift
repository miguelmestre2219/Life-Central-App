import Foundation
import SwiftData

/// Looks back at past sessions to prefill today's sets, suggest the next
/// step up and spot personal records.
enum WorkoutCoach {
    struct History {
        /// Sets done for this exercise in the most recent finished session.
        var lastSets: [SessionSet] = []
        var lastDate: Date?
        var bestEstimatedMax: Double = 0
        var bestWeight: Double = 0
        var bestReps: Int = 0
        var bestSeconds: Int = 0

        var isEmpty: Bool { lastSets.isEmpty }

        /// "40 kg × 8, 8, 7" or "3 × 0:45".
        var lastText: String? {
            guard !lastSets.isEmpty else { return nil }
            if lastSets.allSatisfy({ $0.durationSeconds > 0 }) {
                return lastSets.map { DateText.clock(seconds: $0.durationSeconds) }.joined(separator: ", ")
            }
            let weights = Set(lastSets.map(\.weightKg))
            let reps = lastSets.map { "\($0.reps)" }.joined(separator: ", ")
            if weights.count == 1, let weight = weights.first {
                return weight > 0 ? "\(WeightText.kg(weight)) × \(reps)" : "\(reps) reps"
            }
            return lastSets.map { "\(WeightText.number($0.weightKg))×\($0.reps)" }.joined(separator: ", ")
        }
    }

    struct Suggestion {
        var weightKg: Double
        var reps: Int
        var seconds: Int
        var text: String?
    }

    @MainActor
    static func history(for exerciseID: String, excluding session: WorkoutSession? = nil, in context: ModelContext) -> History {
        let id = exerciseID
        let descriptor = FetchDescriptor<SessionSet>(predicate: #Predicate { $0.exerciseID == id && $0.isDone })
        let sets = ((try? context.fetch(descriptor)) ?? []).filter { set in
            guard let owner = set.session, owner.isFinished else { return false }
            return owner !== session
        }
        var history = History()
        history.bestEstimatedMax = sets.map(\.estimatedMax).max() ?? 0
        history.bestWeight = sets.map(\.weightKg).max() ?? 0
        history.bestReps = sets.map(\.reps).max() ?? 0
        history.bestSeconds = sets.map(\.durationSeconds).max() ?? 0
        let bySession = Dictionary(grouping: sets) { $0.session!.persistentModelID }
        if let latest = bySession.values.max(by: { ($0.first?.session?.startedAt ?? .distantPast) < ($1.first?.session?.startedAt ?? .distantPast) }) {
            history.lastSets = latest.sorted { $0.setIndex < $1.setIndex }
            history.lastDate = latest.first?.session?.startedAt
        }
        return history
    }

    /// What to aim for today, based on last time and the plan.
    static func suggestion(for exerciseID: String, plan: TemplateExercise?, history: History) -> Suggestion {
        let equipment = ExerciseLibrary.exercise(exerciseID)?.equipment
        let targetReps = plan?.reps ?? ExerciseLibrary.exercise(exerciseID)?.plan.reps ?? 10
        let plannedSeconds = plan?.durationSeconds ?? ExerciseLibrary.exercise(exerciseID)?.plan.seconds ?? 0
        let plannedWeight = plan?.weightKg ?? 0

        guard !history.isEmpty else {
            return Suggestion(weightKg: plannedWeight, reps: targetReps, seconds: plannedSeconds, text: nil)
        }
        let last = history.lastSets
        if plannedSeconds > 0 || last.allSatisfy({ $0.durationSeconds > 0 }) {
            let lastBest = last.map(\.durationSeconds).max() ?? plannedSeconds
            let allHit = last.allSatisfy { $0.durationSeconds >= plannedSeconds }
            let seconds = allHit ? lastBest + 5 : lastBest
            return Suggestion(weightKg: 0, reps: 0, seconds: seconds,
                              text: allHit ? "You held every set last time. Try \(DateText.clock(seconds: seconds))." : nil)
        }

        let topWeight = last.map(\.weightKg).max() ?? plannedWeight
        let allHit = last.allSatisfy { $0.reps >= targetReps }
        if topWeight <= 0 {
            let reps = allHit ? (last.map(\.reps).max() ?? targetReps) + 1 : targetReps
            return Suggestion(weightKg: 0, reps: reps, seconds: 0,
                              text: allHit ? "All reps done last time. Try \(reps) per set." : nil)
        }
        if allHit {
            let step: Double = equipment == .dumbbells || equipment == .kettlebell ? 2 : 2.5
            let next = topWeight + step
            return Suggestion(weightKg: next, reps: targetReps, seconds: 0,
                              text: "You hit every rep last time. Try \(WeightText.kg(next)).")
        }
        return Suggestion(weightKg: topWeight, reps: targetReps, seconds: 0,
                          text: "Stay at \(WeightText.kg(topWeight)) until every set reaches \(targetReps).")
    }

    /// True when a finished set beats everything before it.
    static func isRecord(_ set: SessionSet, history: History) -> Bool {
        guard set.isDone else { return false }
        if set.durationSeconds > 0 { return history.bestSeconds > 0 && set.durationSeconds > history.bestSeconds }
        if set.weightKg > 0 { return history.bestEstimatedMax > 0 && set.estimatedMax > history.bestEstimatedMax + 0.01 }
        return history.bestReps > 0 && set.reps > history.bestReps
    }

    /// Creates a session from a workout, with each set prefilled from last time.
    @MainActor
    static func start(_ template: WorkoutTemplate?, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(name: template?.name ?? "Workout", colorHex: template?.colorHex ?? "C2410C")
        context.insert(session)
        session.template = template
        for (order, plan) in (template?.orderedExercises ?? []).enumerated() {
            addSets(exerciseID: plan.exerciseID, name: plan.name, order: order, plan: plan, to: session, in: context)
        }
        return session
    }

    @MainActor
    static func addSets(exerciseID: String, name: String, order: Int, plan: TemplateExercise?, to session: WorkoutSession, in context: ModelContext) {
        let past = history(for: exerciseID, excluding: session, in: context)
        let aim = suggestion(for: exerciseID, plan: plan, history: past)
        let count = plan?.sets ?? ExerciseLibrary.exercise(exerciseID)?.plan.sets ?? 3
        let rest = plan?.restSeconds ?? ExerciseLibrary.exercise(exerciseID)?.plan.rest ?? 90
        for index in 0..<max(1, count) {
            let previous = past.lastSets.indices.contains(index) ? past.lastSets[index] : nil
            let set = SessionSet(exerciseID: exerciseID, exerciseName: name, exerciseOrder: order, setIndex: index,
                                 weightKg: aim.weightKg, reps: aim.reps, restSeconds: rest)
            set.durationSeconds = aim.seconds
            // Without a suggestion step-up, repeat exactly what was done last time.
            if aim.text == nil, let previous {
                set.weightKg = previous.weightKg
                set.reps = previous.reps > 0 ? previous.reps : aim.reps
            }
            context.insert(set)
            set.session = session
        }
    }

    /// Adds one more set to an exercise, copying the one before.
    @MainActor
    static func addSet(to sets: [SessionSet], session: WorkoutSession, in context: ModelContext) {
        guard let last = sets.max(by: { $0.setIndex < $1.setIndex }) else { return }
        let set = SessionSet(exerciseID: last.exerciseID, exerciseName: last.exerciseName, exerciseOrder: last.exerciseOrder,
                             setIndex: last.setIndex + 1, weightKg: last.weightKg, reps: last.reps, restSeconds: last.restSeconds)
        set.durationSeconds = last.durationSeconds
        context.insert(set)
        set.session = session
    }

    /// Writes today's working weights back into the workout plan.
    static func updatePlan(from session: WorkoutSession) {
        guard let template = session.template else { return }
        for group in session.exerciseGroups {
            guard let plan = template.orderedExercises.first(where: { $0.exerciseID == group.id }) else { continue }
            let done = group.sets.filter(\.isDone)
            guard !done.isEmpty else { continue }
            if let top = done.map(\.weightKg).max(), top > 0 { plan.weightKg = top }
            if let seconds = done.map(\.durationSeconds).max(), seconds > 0 { plan.durationSeconds = seconds }
        }
    }

    /// A workout left open when the app was closed. Recent ones come back as
    /// the live workout; old ones are closed at their last ticked set.
    @MainActor
    static func unfinishedSession(in context: ModelContext) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt == nil },
                                                         sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        var keep: WorkoutSession?
        for session in (try? context.fetch(descriptor)) ?? [] {
            if keep == nil && Date.now.timeIntervalSince(session.startedAt) < 12 * 3600 {
                keep = session
                continue
            }
            if let last = session.doneSets.compactMap(\.completedAt).max() {
                session.endedAt = last
                for set in session.sets ?? [] where !set.isDone { context.delete(set) }
            } else {
                context.delete(session)
            }
        }
        return keep
    }
}
