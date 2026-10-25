import SwiftUI
import SwiftData
import Charts

/// How an exercise has gone over time, and how often you train.
struct FitnessProgressView: View {
    let initialExerciseID: String?

    @Query(filter: #Predicate<SessionSet> { $0.isDone }) private var doneSets: [SessionSet]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }, sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @State private var exerciseID: String?
    @State private var selectedDate: Date?
    @State private var selectedWeek: Date?

    private let color = Area.fitness.color

    struct Point: Identifiable {
        let id: PersistentIdentifier
        let date: Date
        let value: Double
        let detail: String
    }

    enum Measure {
        case estimatedMax, seconds, reps
        var title: String {
            switch self {
            case .estimatedMax: "Estimated 1-rep max (kg)"
            case .seconds: "Longest set (seconds)"
            case .reps: "Most reps in a set"
            }
        }
    }

    private var finishedSets: [SessionSet] { doneSets.filter { $0.session?.isFinished == true } }

    /// Exercises you have done, most recent first.
    private var exercises: [(id: String, name: String)] {
        let grouped = Dictionary(grouping: finishedSets, by: \.exerciseID)
        return grouped.compactMap { id, sets -> (id: String, name: String, last: Date)? in
            guard let first = sets.first else { return nil }
            let last = sets.compactMap { $0.session?.startedAt }.max() ?? .distantPast
            return (id: id, name: first.exerciseName, last: last)
        }
        .sorted { $0.last > $1.last }
        .map { (id: $0.id, name: $0.name) }
    }

    private var sets: [SessionSet] { finishedSets.filter { $0.exerciseID == exerciseID } }

    private var measure: Measure {
        if sets.contains(where: { $0.weightKg > 0 }) { return .estimatedMax }
        if sets.contains(where: { $0.durationSeconds > 0 }) { return .seconds }
        return .reps
    }

    private var points: [Point] {
        let bySession = Dictionary(grouping: sets) { $0.session!.persistentModelID }
        return bySession.compactMap { id, sets -> Point? in
            guard let session = sets.first?.session else { return nil }
            let value: Double
            let best: SessionSet?
            switch measure {
            case .estimatedMax:
                best = sets.max { $0.estimatedMax < $1.estimatedMax }
                value = best?.estimatedMax ?? 0
            case .seconds:
                best = sets.max { $0.durationSeconds < $1.durationSeconds }
                value = Double(best?.durationSeconds ?? 0)
            case .reps:
                best = sets.max { $0.reps < $1.reps }
                value = Double(best?.reps ?? 0)
            }
            let detail: String
            if let best {
                detail = best.durationSeconds > 0 ? DateText.clock(seconds: best.durationSeconds)
                    : (best.weightKg > 0 ? "\(WeightText.kg(best.weightKg)) × \(best.reps)" : "\(best.reps) reps")
            } else {
                detail = ""
            }
            return Point(id: id, date: session.startedAt, value: value, detail: detail)
        }
        .sorted { $0.date < $1.date }
    }

    private var selectedPoint: Point? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if exercises.isEmpty {
                    EmptyState(symbol: "chart.line.uptrend.xyaxis", title: "No history yet",
                               message: "Finish a workout and your progress shows up here.")
                        .card()
                } else {
                    exerciseMenu
                    exerciseChart
                    historyTable
                }
                weeklyChart
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if exerciseID == nil { exerciseID = initialExerciseID ?? exercises.first?.id }
        }
    }

    private var exerciseMenu: some View {
        Menu {
            ForEach(exercises, id: \.id) { item in
                Button(item.name) { exerciseID = item.id; selectedDate = nil }
            }
        } label: {
            HStack {
                Text(exercises.first { $0.id == exerciseID }?.name ?? "Choose an exercise").font(.title3.weight(.bold))
                Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.bold))
                Spacer()
            }
            .foregroundStyle(.primary)
        }
    }

    private var exerciseChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(measure.title).font(.subheadline.weight(.semibold))
            if let first = points.first, let last = points.last, points.count > 1 {
                let change = last.value - first.value
                Text(change >= 0 ? "Up \(format(change)) since \(first.date.formatted(.dateTime.day().month(.abbreviated)))"
                                 : "Down \(format(-change)) since \(first.date.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Chart(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(color)
                PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                    .symbolSize(70)
                    .foregroundStyle(color)
                if let selected = selectedPoint, selected.id == point.id {
                    RuleMark(x: .value("Date", selected.date))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selected.date.formatted(.dateTime.day().month(.abbreviated).year()))
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(format(selected.value)).font(.caption.weight(.bold))
                                Text(selected.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 220)
            .accessibilityLabel("\(measure.title) over time")
        }
        .card(padding: 16)
    }

    private var historyTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Each session")
            ForEach(Array(points.reversed())) { point in
                HStack {
                    Text(point.date.formatted(.dateTime.day().month(.abbreviated).year())).foregroundStyle(.secondary)
                    Spacer()
                    Text(point.detail).monospacedDigit()
                    Text(format(point.value)).font(.subheadline.weight(.semibold)).monospacedDigit()
                        .frame(minWidth: 56, alignment: .trailing)
                }
                .font(.subheadline)
            }
        }
        .card(padding: 16)
    }

    // MARK: Workouts per week

    private var weeks: [(start: Date, count: Int)] {
        let thisWeek = Date.now.startOfWeek
        return (0..<12).reversed().map { back in
            let start = Calendar.app.date(byAdding: .weekOfYear, value: -back, to: thisWeek) ?? thisWeek
            let end = Calendar.app.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return (start: start, count: sessions.filter { $0.startedAt >= start && $0.startedAt < end }.count)
        }
    }

    private var weeklyChart: some View {
        let data = weeks
        let selected = selectedWeek.flatMap { date in data.first { date >= $0.start && date < $0.start.adding(days: 7) } }
        let average = Double(data.reduce(0) { $0 + $1.count }) / Double(max(data.count, 1))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Workouts per week").font(.subheadline.weight(.semibold))
            Text("About \(average.formatted(.number.precision(.fractionLength(0...1)))) a week over the last 12 weeks")
                .font(.footnote).foregroundStyle(.secondary)
            Chart(data, id: \.start) { week in
                BarMark(x: .value("Week", week.start, unit: .weekOfYear), y: .value("Workouts", week.count), width: .ratio(0.6))
                    .cornerRadius(4)
                    .foregroundStyle(selected == nil || selected?.start == week.start ? color : color.opacity(0.35))
                    .annotation(position: .top) {
                        if selected?.start == week.start {
                            Text("\(week.count)").font(.caption.weight(.bold))
                        }
                    }
            }
            .chartXSelection(value: $selectedWeek)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 160)
            .accessibilityLabel("Workouts per week for the last 12 weeks")
        }
        .card(padding: 16)
    }

    private func format(_ value: Double) -> String {
        switch measure {
        case .estimatedMax: WeightText.kg(value)
        case .seconds: DateText.clock(seconds: Int(value))
        case .reps: "\(Int(value))"
        }
    }
}
