import Foundation
import HealthKit
import Observation

/// Everything Life Central reads from Apple Health, grouped the way the Health screen shows it.
enum HealthMetric: String, CaseIterable, Identifiable, Hashable {
    case steps, distance, activeEnergy, exerciseMinutes, flights
    case restingHeartRate, heartRate, hrv, vo2Max
    case weight, bodyFat, bmi
    case sleep
    case bloodOxygen, respiratoryRate, systolic, diastolic
    case water, caloriesEaten
    case mindfulness

    var id: String { rawValue }

    enum Group: String, CaseIterable {
        case activity = "Activity", heart = "Heart", body = "Body", sleep = "Sleep"
        case vitals = "Vitals", nutrition = "Nutrition", mind = "Mind"
    }

    var group: Group {
        switch self {
        case .steps, .distance, .activeEnergy, .exerciseMinutes, .flights: .activity
        case .restingHeartRate, .heartRate, .hrv, .vo2Max: .heart
        case .weight, .bodyFat, .bmi: .body
        case .sleep: .sleep
        case .bloodOxygen, .respiratoryRate, .systolic, .diastolic: .vitals
        case .water, .caloriesEaten: .nutrition
        case .mindfulness: .mind
        }
    }

    var title: String {
        switch self {
        case .steps: "Steps"
        case .distance: "Walking and running"
        case .activeEnergy: "Active energy"
        case .exerciseMinutes: "Exercise minutes"
        case .flights: "Flights climbed"
        case .restingHeartRate: "Resting heart rate"
        case .heartRate: "Heart rate"
        case .hrv: "Heart rate variability"
        case .vo2Max: "Cardio fitness (VO₂ max)"
        case .weight: "Weight"
        case .bodyFat: "Body fat"
        case .bmi: "Body mass index"
        case .sleep: "Sleep"
        case .bloodOxygen: "Blood oxygen"
        case .respiratoryRate: "Breathing rate"
        case .systolic: "Blood pressure (systolic)"
        case .diastolic: "Blood pressure (diastolic)"
        case .water: "Water"
        case .caloriesEaten: "Calories eaten"
        case .mindfulness: "Mindful minutes"
        }
    }

    var unit: String {
        switch self {
        case .steps: "steps"
        case .distance: "km"
        case .activeEnergy, .caloriesEaten: "kcal"
        case .exerciseMinutes, .mindfulness: "min"
        case .flights: "floors"
        case .restingHeartRate, .heartRate: "bpm"
        case .hrv: "ms"
        case .vo2Max: "ml/kg/min"
        case .weight: "kg"
        case .bodyFat, .bloodOxygen: "%"
        case .bmi: ""
        case .sleep: "h"
        case .respiratoryRate: "breaths/min"
        case .systolic, .diastolic: "mmHg"
        case .water: "L"
        }
    }

    var icon: String {
        switch self {
        case .steps: "figure.walk"
        case .distance: "map"
        case .activeEnergy: "flame"
        case .exerciseMinutes: "figure.run"
        case .flights: "figure.stairs"
        case .restingHeartRate, .heartRate: "heart"
        case .hrv: "waveform.path.ecg"
        case .vo2Max: "lungs"
        case .weight: "scalemass"
        case .bodyFat, .bmi: "figure.arms.open"
        case .sleep: "bed.double"
        case .bloodOxygen: "drop.circle"
        case .respiratoryRate: "wind"
        case .systolic, .diastolic: "heart.text.square"
        case .water: "drop"
        case .caloriesEaten: "fork.knife"
        case .mindfulness: "brain.head.profile"
        }
    }

    /// Daily totals add up (steps); the rest are averaged per day (heart rate).
    var isTotal: Bool {
        switch self {
        case .steps, .distance, .activeEnergy, .exerciseMinutes, .flights, .water, .caloriesEaten, .sleep, .mindfulness: true
        default: false
        }
    }

    /// Weight and water can be logged from the app.
    var logKind: HealthLogKind? {
        switch self {
        case .weight: .weight
        case .water: .water
        default: nil
        }
    }

    fileprivate var quantity: (id: HKQuantityTypeIdentifier, unit: HKUnit, scale: Double)? {
        switch self {
        case .steps: (.stepCount, .count(), 1)
        case .distance: (.distanceWalkingRunning, .meterUnit(with: .kilo), 1)
        case .activeEnergy: (.activeEnergyBurned, .kilocalorie(), 1)
        case .exerciseMinutes: (.appleExerciseTime, .minute(), 1)
        case .flights: (.flightsClimbed, .count(), 1)
        case .restingHeartRate: (.restingHeartRate, HKUnit.count().unitDivided(by: .minute()), 1)
        case .heartRate: (.heartRate, HKUnit.count().unitDivided(by: .minute()), 1)
        case .hrv: (.heartRateVariabilitySDNN, .secondUnit(with: .milli), 1)
        case .vo2Max: (.vo2Max, HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())), 1)
        case .weight: (.bodyMass, .gramUnit(with: .kilo), 1)
        case .bodyFat: (.bodyFatPercentage, .percent(), 100)
        case .bmi: (.bodyMassIndex, .count(), 1)
        case .bloodOxygen: (.oxygenSaturation, .percent(), 100)
        case .respiratoryRate: (.respiratoryRate, HKUnit.count().unitDivided(by: .minute()), 1)
        case .systolic: (.bloodPressureSystolic, .millimeterOfMercury(), 1)
        case .diastolic: (.bloodPressureDiastolic, .millimeterOfMercury(), 1)
        case .water: (.dietaryWater, .liter(), 1)
        case .caloriesEaten: (.dietaryEnergyConsumed, .kilocalorie(), 1)
        case .sleep, .mindfulness: nil
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .steps, .activeEnergy, .caloriesEaten, .flights, .exerciseMinutes, .mindfulness, .restingHeartRate, .heartRate,
             .hrv, .systolic, .diastolic:
            Int(value.rounded()).formatted()
        case .sleep:
            DateText.duration(minutes: Int((value * 60).rounded()))
        default:
            value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    /// "8,412 steps", "7 h 20 min", "72.4 kg".
    func text(_ value: Double) -> String {
        if self == .sleep || unit.isEmpty { return format(value) }
        return "\(format(value)) \(unit)"
    }
}

struct HealthPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let value: Double
}

/// Reads and writes Apple Health. Everything stays on the phone; nothing here
/// leaves the device.
@Observable
final class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    private(set) var isConnected = UserDefaults.standard.bool(forKey: SettingsKey.healthConnected)
    private(set) var stepsToday: Double?
    /// The most recent day with data for each metric.
    private(set) var latest: [HealthMetric: HealthPoint] = [:]
    private(set) var isLoading = false

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType(), HKCategoryType(.sleepAnalysis), HKCategoryType(.mindfulSession)]
        for metric in HealthMetric.allCases {
            if let q = metric.quantity { types.insert(HKQuantityType(q.id)) }
        }
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.bodyMass), HKQuantityType(.dietaryWater)]
    }

    /// Shows Apple's permission sheet. Health never says which types were
    /// refused, so anything refused simply shows no data.
    @MainActor
    @discardableResult
    func connect() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isConnected = true
            UserDefaults.standard.set(true, forKey: SettingsKey.healthConnected)
            await refreshToday()
            return true
        } catch {
            return false
        }
    }

    @MainActor
    func refreshToday() async {
        guard isAvailable, isConnected else { return }
        stepsToday = await series(.steps, days: 1).last?.value
    }

    /// Latest value of every metric, looking back up to a month.
    @MainActor
    func refreshAll() async {
        guard isAvailable, isConnected, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        var found: [HealthMetric: HealthPoint] = [:]
        await withTaskGroup(of: (HealthMetric, HealthPoint?).self) { group in
            for metric in HealthMetric.allCases {
                group.addTask {
                    let points = await self.series(metric, days: 30)
                    return (metric, points.last { $0.value > 0 })
                }
            }
            for await (metric, point) in group {
                if let point { found[metric] = point }
            }
        }
        latest = found
        stepsToday = found[.steps].flatMap { $0.date.isToday ? $0.value : 0 }
    }

    /// One value per day, oldest first. Days with no data are left out.
    func series(_ metric: HealthMetric, days: Int) async -> [HealthPoint] {
        guard isAvailable else { return [] }
        let end = Date.now
        let start = Date.now.startOfDay.adding(days: -(days - 1))
        switch metric {
        case .sleep: return await sleep(from: start, to: end)
        case .mindfulness: return await mindful(from: start, to: end)
        default: break
        }
        guard let q = metric.quantity else { return [] }
        let type = HKQuantityType(q.id)
        let predicate = HKSamplePredicate.quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: metric.isTotal ? .cumulativeSum : .discreteAverage,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1))
        guard let collection = try? await descriptor.result(for: store) else { return [] }
        var points: [HealthPoint] = []
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let quantity = metric.isTotal ? stats.sumQuantity() : stats.averageQuantity()
            if let quantity {
                points.append(HealthPoint(date: stats.startDate, value: quantity.doubleValue(for: q.unit) * q.scale))
            }
        }
        return points
    }

    /// Hours asleep per night, credited to the morning you woke up.
    private func sleep(from start: Date, to end: Date) async -> [HealthPoint] {
        let samples = await categorySamples(.sleepAnalysis, from: start.adding(days: -1), to: end)
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let nights = Dictionary(grouping: samples.filter { asleep.contains($0.value) }) { $0.endDate.startOfDay }
        return nights.compactMap { day, samples -> HealthPoint? in
            guard day >= start.startOfDay else { return nil }
            // Watch and phone can both record the same night; merge overlaps.
            let intervals = samples.map { ($0.startDate, $0.endDate) }.sorted { $0.0 < $1.0 }
            var total: TimeInterval = 0
            var current: (Date, Date)?
            for interval in intervals {
                if let c = current, interval.0 <= c.1 {
                    current = (c.0, max(c.1, interval.1))
                } else {
                    if let c = current { total += c.1.timeIntervalSince(c.0) }
                    current = interval
                }
            }
            if let c = current { total += c.1.timeIntervalSince(c.0) }
            return HealthPoint(date: day, value: total / 3600)
        }
        .sorted { $0.date < $1.date }
    }

    private func mindful(from start: Date, to end: Date) async -> [HealthPoint] {
        let samples = await categorySamples(.mindfulSession, from: start, to: end)
        let days = Dictionary(grouping: samples) { $0.startDate.startOfDay }
        return days.map { day, samples in
            HealthPoint(date: day, value: samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60)
        }
        .sorted { $0.date < $1.date }
    }

    private func categorySamples(_ id: HKCategoryTypeIdentifier, from start: Date, to end: Date) async -> [HKCategorySample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(id), predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return (try? await descriptor.result(for: store)) ?? []
    }

    // MARK: Writing

    @discardableResult
    func saveWorkout(_ session: WorkoutSession) async -> Bool {
        guard isAvailable, isConnected else { return false }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType(for: session)
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        let end = session.endedAt ?? .now
        do {
            try await builder.beginCollection(at: session.startedAt)
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Life Central"])
            try await builder.endCollection(at: end)
            return try await builder.finishWorkout() != nil
        } catch {
            return false
        }
    }

    private func activityType(for session: WorkoutSession) -> HKWorkoutActivityType {
        let ids = Set((session.sets ?? []).map(\.exerciseID))
        if ids == ["running"] { return .running }
        if ids == ["cycling"] { return .cycling }
        if ids == ["rowing-machine"] { return .rowing }
        if ids == ["walking"] { return .walking }
        switch session.template?.kind {
        case .cardio: return .mixedCardio
        case .mobility: return .flexibility
        default: return .traditionalStrengthTraining
        }
    }

    func saveWeight(kg: Double, at date: Date) async {
        await save(.bodyMass, HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg), at: date)
    }

    func saveWater(ml: Double, at date: Date) async {
        await save(.dietaryWater, HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml), at: date)
    }

    private func save(_ id: HKQuantityTypeIdentifier, _ quantity: HKQuantity, at date: Date) async {
        guard isAvailable, isConnected else { return }
        let sample = HKQuantitySample(type: HKQuantityType(id), quantity: quantity, start: date, end: date)
        try? await store.save(sample)
    }
}
