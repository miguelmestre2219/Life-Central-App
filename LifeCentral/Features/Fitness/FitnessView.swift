import SwiftUI
import SwiftData

struct FitnessView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var month = Date.now.startOfMonth
    @State private var selectedDay = Date.now.startOfDay

    private let color = Area.fitness.color

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                startCard
                weekStats
                calendar
                daySessions
                library
                guides
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("Fitness")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.health) { Image(systemName: Area.health.icon) }
                    .accessibilityLabel("Health")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.progress(nil)) { Image(systemName: "chart.line.uptrend.xyaxis") }
                    .accessibilityLabel("Progress")
            }
        }
    }

    // MARK: Start

    @ViewBuilder
    private var startCard: some View {
        if let live = router.liveSession {
            Button { router.isLiveExpanded = true } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "figure.strengthtraining.traditional", color: .white, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout in progress").font(.caption.weight(.semibold)).opacity(0.85)
                        Text(live.name).font(.headline)
                        Text("\(live.doneSets.count) sets done").font(.footnote).opacity(0.85)
                    }
                    Spacer()
                    Text("Open").font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.white, in: Capsule())
                        .foregroundStyle(Color(hex: live.colorHex))
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(Color(hex: live.colorHex), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Button { router.present(.startWorkout) } label: {
                HStack(spacing: 12) {
                    IconChip(symbol: "play.fill", color: .white, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start a workout").font(.headline)
                        Text(lastWorkoutText).font(.footnote).opacity(0.85)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(.white)
                .padding(16)
                .background(color, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var lastWorkoutText: String {
        guard let last = sessions.first else { return "Pick one from your workouts below" }
        return "Last: \(last.name), \(DateText.countdown(last.startedAt))"
    }

    // MARK: This week

    private var weekStats: some View {
        let start = Date.now.startOfWeek
        let week = sessions.filter { $0.startedAt >= start }
        let minutes = week.reduce(0) { $0 + $1.durationMinutes }
        let volume = week.reduce(0.0) { $0 + $1.volumeKg }
        return HStack(spacing: 10) {
            stat("\(week.count)", "workouts this week")
            stat(DateText.duration(minutes: minutes), "time trained")
            stat(volume >= 1000 ? "\(WeightText.number(volume / 1000)) t" : WeightText.kg(volume), "lifted")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .card(padding: 12)
    }

    // MARK: Calendar

    private var calendar: some View {
        VStack(spacing: 10) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button { month = month.adding(months: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Button { month = month.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
                    .padding(.leading, 12)
            }
            .tint(color)
            MonthGrid(month: month, selected: $selectedDay, sessions: sessions)
        }
        .card()
    }

    @ViewBuilder
    private var daySessions: some View {
        let onDay = sessions.filter { $0.startedAt.isSameDay(as: selectedDay) }
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: selectedDay.isToday ? "Today" : DateText.relativeDay(selectedDay))
            if onDay.isEmpty {
                if selectedDay.isToday {
                    Text("Nothing yet today. Tap a workout below to start it.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if selectedDay > Date.now {
                    Text("Come back on the day and start a workout from your list.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Rest day.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach(onDay) { session in
                NavigationLink(value: Route.session(session)) {
                    HStack(spacing: 12) {
                        Circle().fill(Color(hex: session.colorHex)).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("\(DateText.time(session.startedAt)) · \(DateText.duration(minutes: session.durationMinutes)) · \(session.doneSets.count) sets")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    // MARK: Library

    private var library: some View {
        VStack(spacing: 8) {
            HStack {
                SectionLabel(text: "Your workouts")
                Button { router.present(.newWorkout) } label: { Label("New", systemImage: "plus") }
                    .font(.subheadline.weight(.semibold))
                    .tint(color)
            }
            if templates.isEmpty {
                EmptyState(symbol: "dumbbell", title: "No workouts yet", message: "Build a workout once, then start it whenever you like.",
                           actionTitle: "New workout", color: color) { router.present(.newWorkout) }
                    .card()
            }
            ForEach(templates) { template in
                WorkoutCard(template: template) { start(template) }
            }
        }
    }

    private var guides: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Exercise guides")
                NavigationLink(value: Route.exercises) { Text("See all") }
                    .font(.subheadline.weight(.semibold))
                    .tint(color)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(["squat", "bench-press", "deadlift", "lat-pulldown", "plank", "kettlebell-swing"], id: \.self) { id in
                        if let exercise = ExerciseLibrary.exercise(id) {
                            NavigationLink(value: Route.exerciseGuide(id)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ExerciseFigure(motion: exercise.motion, isPlaying: false, stillAt: 0.6)
                                        .frame(width: 110, height: 110)
                                    Text(exercise.name).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                }
                                .frame(width: 110)
                                .padding(10)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func start(_ template: WorkoutTemplate) {
        if router.liveSession != nil {
            router.isLiveExpanded = true
            return
        }
        router.startWorkout(WorkoutCoach.start(template, in: context))
    }
}

struct WorkoutCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void

    var body: some View {
        let color = Color(hex: template.colorHex)
        HStack(spacing: 0) {
            NavigationLink(value: Route.workoutTemplate(template)) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 6)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(template.name).font(.headline).foregroundStyle(.primary)
                            if !template.sharedBy.isEmpty {
                                Text("from \(template.sharedBy)").font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Area.friends.tint, in: Capsule())
                                    .foregroundStyle(Area.friends.color)
                            }
                        }
                        Text(template.orderedExercises.prefix(3).map(\.name).joined(separator: ", ")
                             + (template.orderedExercises.count > 3 ? " +\(template.orderedExercises.count - 3)" : ""))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text("~\(template.estimatedMinutes) min" + (template.lastSession.map { " · last \(DateText.countdown($0.startedAt))" } ?? ""))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 12)
                .padding(.leading, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .accessibilityLabel("Start \(template.name)")
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// A month of days with a dot for each workout done.
struct MonthGrid: View {
    let month: Date
    @Binding var selected: Date
    let sessions: [WorkoutSession]

    private var days: [Date?] {
        let first = month.startOfMonth
        let count = Calendar.app.range(of: .day, in: .month, for: first)?.count ?? 30
        let weekday = Calendar.app.component(.weekday, from: first)
        let lead = (weekday - Calendar.app.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + (0..<count).map { first.adding(days: $0) }
    }

    private var symbols: [String] {
        let all = Calendar.app.veryShortStandaloneWeekdaySymbols
        let start = Calendar.app.firstWeekday - 1
        return Array(all[start...] + all[..<start])
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    let done = sessions.filter { $0.startedAt.isSameDay(as: day) }
                    let isSelected = day.isSameDay(as: selected)
                    Button { selected = day } label: {
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.day()))
                                .font(.subheadline.weight(day.isToday ? .bold : .regular))
                                .foregroundStyle(isSelected ? .white : (day.isToday ? Area.fitness.color : .primary))
                                .frame(width: 32, height: 32)
                                .background(isSelected ? Area.fitness.color : .clear, in: Circle())
                            HStack(spacing: 2) {
                                ForEach(done.prefix(3)) { session in
                                    Circle().fill(Color(hex: session.colorHex)).frame(width: 5, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(done.count) workout\(done.count == 1 ? "" : "s")")
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }
}
