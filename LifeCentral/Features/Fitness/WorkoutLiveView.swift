import SwiftUI
import SwiftData

/// The gym screen: one exercise at a time, sets prefilled from last time,
/// a suggestion for today, a rest timer and personal records.
struct WorkoutLiveView: View {
    @Bindable var session: WorkoutSession

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @State private var timer = WorkoutTimer()
    @State private var histories: [String: WorkoutCoach.History] = [:]
    @State private var records: Set<PersistentIdentifier> = []
    @State private var showPicker = false
    @State private var showFinish = false
    @State private var guideID: String?
    @State private var confirmDiscard = false
    @FocusState private var focused: Bool

    private var color: Color { Color(hex: session.colorHex) }
    private var groups: [(order: Int, id: String, name: String, sets: [SessionSet])] { session.exerciseGroups }
    private var currentIndex: Int { min(max(session.currentExerciseIndex, 0), max(groups.count - 1, 0)) }
    private var current: (order: Int, id: String, name: String, sets: [SessionSet])? {
        groups.indices.contains(currentIndex) ? groups[currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                exerciseStrip
                ScrollView {
                    if let current {
                        exerciseCard(current)
                            .padding(.horizontal, Theme.gutter)
                            .padding(.top, 8)
                    } else {
                        EmptyState(symbol: "plus", title: "Add your first exercise", message: "Pick from the guides or create your own.",
                                   actionTitle: "Add exercise", color: color) { showPicker = true }
                            .padding(.top, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                bottomBar
            }
            .screenBackground()
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { router.isLiveExpanded = false } label: { Image(systemName: "chevron.down") }
                        .accessibilityLabel("Minimise")
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(session.name).font(.subheadline.weight(.semibold))
                        Text(session.startedAt, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showPicker = true } label: { Label("Add exercise", systemImage: "plus") }
                        Button("Discard workout", role: .destructive) { confirmDiscard = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finishTapped() }.fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .tint(color)
            .sheet(isPresented: $showPicker) {
                ExercisePicker(color: color) { picked in add(picked) }
            }
            .sheet(isPresented: $showFinish) {
                FinishWorkoutSheet(session: session, records: records.count) { finish() }
            }
            .sheet(item: Binding(get: { guideID.map(GuideID.init) }, set: { guideID = $0?.id })) { item in
                NavigationStack {
                    ExerciseGuideView(exerciseID: item.id)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { guideID = nil } } }
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { discard() }
            } message: {
                Text("Nothing from this session will be saved.")
            }
            .onAppear(perform: loadHistories)
            .onChange(of: timer.finishedCount) { _, _ in timerFinished() }
            .sensoryFeedback(.success, trigger: timer.finishedCount)
            .sensoryFeedback(.impact(weight: .heavy), trigger: records.count)
        }
    }

    // MARK: Exercise strip

    private var exerciseStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(groups.enumerated()), id: \.element.order) { index, group in
                        let done = group.sets.filter(\.isDone).count
                        Button { session.currentExerciseIndex = index } label: {
                            HStack(spacing: 6) {
                                if done == group.sets.count && done > 0 {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(group.name).lineLimit(1)
                                Text("\(done)/\(group.sets.count)").foregroundStyle(index == currentIndex ? .white.opacity(0.8) : .secondary)
                            }
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(index == currentIndex ? .white : .primary)
                            .background(index == currentIndex ? color : Theme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .contextMenu {
                            Button("Remove from this workout", role: .destructive) { remove(group.sets) }
                        }
                    }
                    Button { showPicker = true } label: {
                        Image(systemName: "plus").font(.footnote.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(Theme.card, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add exercise")
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 10)
            }
            .onChange(of: session.currentExerciseIndex) { _, index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }

    // MARK: Current exercise

    private func exerciseCard(_ group: (order: Int, id: String, name: String, sets: [SessionSet])) -> some View {
        let exercise = ExerciseLibrary.exercise(group.id)
        let history = histories[group.id] ?? WorkoutCoach.History()
        let plan = session.template?.orderedExercises.first { $0.exerciseID == group.id }
        let aim = WorkoutCoach.suggestion(for: group.id, plan: plan, history: history)
        let isTimed = group.sets.contains { $0.durationSeconds > 0 }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                if let exercise {
                    ExerciseFigure(motion: exercise.motion, accent: color)
                        .frame(width: 84, height: 84)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 14))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name).font(.title3.weight(.bold))
                    if let last = history.lastText, let date = history.lastDate {
                        Label("Last time: \(last), \(DateText.countdown(date))", systemImage: "clock.arrow.circlepath")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Label("First time. Pick a weight you can lift with good form.", systemImage: "sparkles")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if exercise != nil {
                        Button("How to do it") { guideID = group.id }
                            .font(.footnote.weight(.semibold))
                    }
                }
            }

            if let text = aim.text {
                Label(text, systemImage: "arrow.up.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 6) {
                HStack {
                    Text("SET").frame(width: 34, alignment: .leading)
                    Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
                    if isTimed {
                        Text("TIME").frame(width: 150)
                    } else {
                        Text("KG").frame(width: 76)
                        Text("REPS").frame(width: 56)
                    }
                    Text("").frame(width: 36)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

                ForEach(group.sets) { set in
                    let previous = history.lastSets.first { $0.setIndex == set.setIndex }
                    SetRow(set: set, previous: previous, isTimed: isTimed, isRecord: records.contains(set.persistentModelID),
                           color: color, focused: $focused,
                           isHolding: timer.isRunning && timer.kind == .hold && holdingSet == set.persistentModelID) {
                        toggle(set, in: group)
                    } onHold: {
                        startHold(set, name: group.name)
                    }
                }
            }

            HStack {
                Button { WorkoutCoach.addSet(to: group.sets, session: session, in: context) } label: {
                    Label("Add set", systemImage: "plus")
                }
                Spacer()
                if group.sets.count > 1, let last = group.sets.last, !last.isDone {
                    Button(role: .destructive) { context.delete(last) } label: {
                        Label("Remove set", systemImage: "minus")
                    }
                    .tint(.secondary)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .card(padding: 16)
    }

    @State private var holdingSet: PersistentIdentifier?

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let end = timer.endDate, let start = timer.startDate {
            VStack(spacing: 8) {
                HStack {
                    Text(timer.kind == .rest ? "Rest" : "Hold").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(timerInterval: Date.now...max(end, Date.now), countsDown: true)
                        .font(.title2.weight(.bold).monospacedDigit())
                }
                ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(color)
                HStack(spacing: 10) {
                    Button("−15 s") { timer.adjust(by: -15, message: nextMessage) }
                    Button("+15 s") { timer.adjust(by: 15, message: nextMessage) }
                    Spacer()
                    Button(timer.kind == .rest ? "Skip rest" : "Stop") {
                        let wasHold = timer.kind == .hold
                        timer.cancel()
                        if wasHold { holdingSet = nil }
                    }
                    .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .font(.footnote)
            }
            .padding(16)
            .background(.regularMaterial)
        } else if !groups.isEmpty {
            HStack(spacing: 10) {
                Button {
                    session.currentExerciseIndex = max(0, currentIndex - 1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(currentIndex == 0)
                .accessibilityLabel("Previous exercise")
                Button {
                    if currentIndex < groups.count - 1 {
                        session.currentExerciseIndex = currentIndex + 1
                    } else {
                        finishTapped()
                    }
                } label: {
                    Text(currentIndex < groups.count - 1 ? "Next: \(groups[currentIndex + 1].name)" : "Finish workout")
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    private var nextMessage: String {
        guard let current else { return "Time for your next set." }
        if let next = current.sets.first(where: { !$0.isDone }) {
            return "Next: \(current.name), set \(next.setIndex + 1)"
        }
        if groups.indices.contains(currentIndex + 1) {
            return "Next: \(groups[currentIndex + 1].name)"
        }
        return "Last set done. Finish when ready."
    }

    // MARK: Actions

    private func loadHistories() {
        for group in groups where histories[group.id] == nil {
            histories[group.id] = WorkoutCoach.history(for: group.id, excluding: session, in: context)
        }
    }

    private func toggle(_ set: SessionSet, in group: (order: Int, id: String, name: String, sets: [SessionSet])) {
        focused = false
        set.isDone.toggle()
        set.completedAt = set.isDone ? .now : nil
        if !set.isDone {
            records.remove(set.persistentModelID)
            return
        }
        checkRecord(set, in: group)
        let remaining = group.sets.filter { !$0.isDone }
        if remaining.isEmpty, currentIndex < groups.count - 1 {
            // Show the next exercise straight away; the rest timer runs underneath.
            timer.start(seconds: set.restSeconds, kind: .rest, message: "Next: \(groups[currentIndex + 1].name)")
            session.currentExerciseIndex = currentIndex + 1
        } else {
            timer.start(seconds: set.restSeconds, kind: .rest, message: nextMessage)
        }
    }

    private func checkRecord(_ set: SessionSet, in group: (order: Int, id: String, name: String, sets: [SessionSet])) {
        var best = histories[group.id] ?? WorkoutCoach.History()
        for other in group.sets where other.isDone && other !== set {
            best.bestEstimatedMax = max(best.bestEstimatedMax, other.estimatedMax)
            best.bestReps = max(best.bestReps, other.reps)
            best.bestSeconds = max(best.bestSeconds, other.durationSeconds)
        }
        if WorkoutCoach.isRecord(set, history: best) {
            records.insert(set.persistentModelID)
        }
    }

    private func startHold(_ set: SessionSet, name: String) {
        focused = false
        holdingSet = set.persistentModelID
        timer.start(seconds: set.durationSeconds, kind: .hold, message: "\(name): set \(set.setIndex + 1) done")
    }

    private func timerFinished() {
        guard timer.lastFinishedKind == .hold, let id = holdingSet else { return }
        holdingSet = nil
        guard let group = current, let set = group.sets.first(where: { $0.persistentModelID == id }), !set.isDone else { return }
        toggle(set, in: group)
    }

    private func add(_ picked: [PickedExercise]) {
        var order = (groups.map(\.order).max() ?? -1) + 1
        let firstNew = groups.count
        for choice in picked {
            let plan = session.template?.orderedExercises.first { $0.exerciseID == choice.id }
            WorkoutCoach.addSets(exerciseID: choice.id, name: choice.name, order: order, plan: plan, to: session, in: context)
            order += 1
        }
        loadHistories()
        if !picked.isEmpty { session.currentExerciseIndex = firstNew }
    }

    private func remove(_ sets: [SessionSet]) {
        for set in sets { context.delete(set) }
        session.currentExerciseIndex = max(0, min(session.currentExerciseIndex, groups.count - 2))
    }

    private func finishTapped() {
        focused = false
        showFinish = true
    }

    private func finish() {
        timer.cancel()
        session.endedAt = .now
        // Drop sets that were never done so history stays honest.
        for set in session.sets ?? [] where !set.isDone { context.delete(set) }
        router.isLiveExpanded = false
        router.liveSession = nil
        router.show(.session(session))
    }

    private func discard() {
        timer.cancel()
        router.isLiveExpanded = false
        router.liveSession = nil
        // Delete after the screen has gone, so nothing reads the removed session.
        let doomed = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { context.delete(doomed) }
    }
}

private struct GuideID: Identifiable {
    let id: String
}

/// One set: last time's numbers, today's weight and reps, and the tick.
struct SetRow: View {
    @Bindable var set: SessionSet
    let previous: SessionSet?
    let isTimed: Bool
    let isRecord: Bool
    let color: Color
    var focused: FocusState<Bool>.Binding
    let isHolding: Bool
    let onToggle: () -> Void
    let onHold: () -> Void

    var body: some View {
        HStack {
            Text("\(set.setIndex + 1)")
                .font(.subheadline.weight(.bold))
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(previousText).font(.footnote).foregroundStyle(.secondary)
                if isRecord {
                    Label("PR", systemImage: "trophy.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isTimed {
                HStack(spacing: 6) {
                    Button { set.durationSeconds = max(5, set.durationSeconds - 5) } label: { Image(systemName: "minus") }
                        .accessibilityLabel("5 seconds less")
                    Text(DateText.clock(seconds: set.durationSeconds))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 48)
                    Button { set.durationSeconds += 5 } label: { Image(systemName: "plus") }
                        .accessibilityLabel("5 seconds more")
                    Button(action: onHold) { Image(systemName: isHolding ? "timer" : "play.fill") }
                        .disabled(set.isDone || isHolding)
                        .accessibilityLabel("Start timer")
                }
                .buttonStyle(.borderless)
                .frame(width: 150)
            } else {
                DecimalField(value: $set.weightKg, placeholder: "kg")
                    .focused(focused)
                    .frame(width: 76)
                IntegerField(value: $set.reps, placeholder: "reps")
                    .focused(focused)
                    .frame(width: 56)
            }

            Button(action: onToggle) { CircleTick(isOn: set.isDone, color: color, size: 30) }
                .buttonStyle(.plain)
                .frame(width: 36)
                .accessibilityLabel(set.isDone ? "Set \(set.setIndex + 1) done" : "Mark set \(set.setIndex + 1) done")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(set.isDone ? color.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private var previousText: String {
        guard let previous else { return "–" }
        if previous.durationSeconds > 0 { return DateText.clock(seconds: previous.durationSeconds) }
        if previous.weightKg > 0 { return "\(WeightText.number(previous.weightKg)) × \(previous.reps)" }
        return "\(previous.reps) reps"
    }
}

/// A number box that saves as you type (value-bound text fields only save on Return).
struct DecimalField: View {
    @Binding var value: Double
    var placeholder = ""
    var font: Font = .body.monospacedDigit().weight(.semibold)
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(font)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .onAppear { text = value == 0 ? "" : WeightText.number(value) }
            .onChange(of: text) { _, newText in
                let cleaned = newText.replacingOccurrences(of: ",", with: ".")
                value = Double(cleaned) ?? 0
            }
            .onChange(of: value) { _, newValue in
                let shown = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
                if abs(shown - newValue) > 0.001 { text = newValue == 0 ? "" : WeightText.number(newValue) }
            }
    }
}

struct IntegerField: View {
    @Binding var value: Int
    var placeholder = ""
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.body.monospacedDigit().weight(.semibold))
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .onAppear { text = value == 0 ? "" : "\(value)" }
            .onChange(of: text) { _, newText in value = Int(newText) ?? 0 }
            .onChange(of: value) { _, newValue in
                if Int(text) ?? 0 != newValue { text = newValue == 0 ? "" : "\(newValue)" }
            }
    }
}
