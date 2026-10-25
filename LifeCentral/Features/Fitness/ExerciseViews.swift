import SwiftUI
import SwiftData

struct PickedExercise: Hashable {
    let id: String
    let name: String
}

/// Choose one or more exercises: built-in ones with their cartoon, plus your own.
struct ExercisePicker: View {
    var color: Color = Area.fitness.color
    var allowsMultiple = true
    let onPick: ([PickedExercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomExercise.name) private var custom: [CustomExercise]
    @State private var query = ""
    @State private var muscle: Muscle?
    @State private var chosen: [PickedExercise] = []
    @State private var showCustom = false

    private var builtIn: [Exercise] {
        ExerciseLibrary.all.filter { exercise in
            (muscle == nil || exercise.muscle == muscle) &&
            (query.isEmpty || exercise.name.localizedCaseInsensitiveContains(query))
        }
    }

    private var mine: [CustomExercise] {
        custom.filter { item in
            (muscle == nil || item.muscleRaw == muscle?.rawValue) &&
            (query.isEmpty || item.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ChoiceChip(title: "All", isOn: muscle == nil, color: color) { muscle = nil }
                            ForEach(Muscle.allCases) { item in
                                ChoiceChip(title: item.title, isOn: muscle == item, color: color) { muscle = item }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                if !mine.isEmpty {
                    Section("Your exercises") {
                        ForEach(mine) { item in
                            row(PickedExercise(id: item.exerciseID, name: item.name), detail: item.equipment, figure: nil)
                        }
                    }
                }

                Section {
                    ForEach(builtIn) { exercise in
                        row(PickedExercise(id: exercise.id, name: exercise.name),
                            detail: "\(exercise.muscle.title) · \(exercise.equipment.title)", figure: exercise.motion)
                    }
                    Button { showCustom = true } label: { Label("Create your own exercise", systemImage: "plus") }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .tint(color)
            .navigationTitle("Add exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(chosen.isEmpty ? "Add" : "Add \(chosen.count)") {
                        onPick(chosen)
                        dismiss()
                    }
                    .disabled(chosen.isEmpty)
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showCustom) {
                CustomExerciseForm { created in
                    chosen.append(PickedExercise(id: created.exerciseID, name: created.name))
                }
            }
        }
    }

    private func row(_ pick: PickedExercise, detail: String, figure: Motion?) -> some View {
        let isOn = chosen.contains(pick)
        return Button {
            if isOn {
                chosen.removeAll { $0 == pick }
            } else if allowsMultiple {
                chosen.append(pick)
            } else {
                onPick([pick])
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                if let figure {
                    ExerciseFigure(motion: figure, isPlaying: false, stillAt: 0.5)
                        .frame(width: 48, height: 48)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
                } else {
                    IconChip(symbol: "dumbbell", color: color, size: 48)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.name).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if allowsMultiple {
                    CircleTick(isOn: isOn, color: color, size: 24)
                }
            }
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct CustomExerciseForm: View {
    var onCreate: (CustomExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var muscle: Muscle = .chest
    @State private var equipment: Equipment = .machine
    @State private var steps = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name, e.g. Pec deck", text: $name)
                Picker("Main muscle", selection: $muscle) {
                    ForEach(Muscle.allCases) { Text($0.title).tag($0) }
                }
                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                }
                Section("How to do it (optional)") {
                    TextField("A few notes to remember", text: $steps, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = CustomExercise(name: name.trimmingCharacters(in: .whitespaces), muscle: muscle.rawValue, equipment: equipment.title)
                        item.steps = steps
                        context.insert(item)
                        onCreate(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

/// Every built-in exercise, grouped by muscle.
struct ExerciseBrowserView: View {
    @State private var query = ""
    @Query(sort: \CustomExercise.name) private var custom: [CustomExercise]

    var body: some View {
        List {
            ForEach(Muscle.allCases) { muscle in
                let items = ExerciseLibrary.exercises(for: muscle).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                if !items.isEmpty {
                    Section(muscle.title) {
                        ForEach(items) { exercise in
                            NavigationLink(value: Route.exerciseGuide(exercise.id)) {
                                HStack(spacing: 12) {
                                    ExerciseFigure(motion: exercise.motion, isPlaying: false, stillAt: 0.5)
                                        .frame(width: 48, height: 48)
                                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                        Text(exercise.equipment.title).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            let mine = custom.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            if !mine.isEmpty {
                Section("Your exercises") {
                    ForEach(mine) { item in
                        NavigationLink(value: Route.exerciseGuide(item.exerciseID)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                Text(item.equipment).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search exercises")
        .navigationTitle("Exercise guides")
    }
}

/// How to do an exercise: the moving cartoon, steps, mistakes and your history.
struct ExerciseGuideView: View {
    let exerciseID: String

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]
    @Query private var custom: [CustomExercise]
    @State private var isPlaying = true
    @State private var slow = false
    @State private var history = WorkoutCoach.History()
    @State private var addedTo: String?

    private var exercise: Exercise? { ExerciseLibrary.exercise(exerciseID) }
    private var customExercise: CustomExercise? { custom.first { $0.exerciseID == exerciseID } }
    private var color: Color { Area.fitness.color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let exercise {
                    figureCard(exercise)
                    header(name: exercise.name, muscles: exercise.musclesText, equipment: exercise.equipment.title)
                    numbered("How to do it", exercise.steps)
                    bullets("Common mistakes", exercise.mistakes)
                    Label(exercise.tip, systemImage: "lightbulb")
                        .font(.subheadline)
                        .card()
                } else if let customExercise {
                    header(name: customExercise.name, muscles: Muscle(rawValue: customExercise.muscleRaw)?.title ?? "", equipment: customExercise.equipment)
                    if !customExercise.steps.isEmpty {
                        Text(customExercise.steps).card()
                    }
                } else {
                    EmptyState(symbol: "questionmark", title: "Exercise not found", message: "It may have been deleted.")
                }
                historyCard
                addToWorkout
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(exercise?.name ?? customExercise?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { history = WorkoutCoach.history(for: exerciseID, in: context) }
    }

    private func figureCard(_ exercise: Exercise) -> some View {
        VStack(spacing: 8) {
            if reduceMotion {
                HStack(spacing: 8) {
                    still(exercise, at: 0, label: "Start")
                    still(exercise, at: 1, label: "Finish")
                }
            } else {
                ExerciseFigure(motion: exercise.motion, isPlaying: isPlaying, speed: slow ? 0.5 : 1)
                    .frame(maxWidth: 320)
                HStack(spacing: 10) {
                    Button { isPlaying.toggle() } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button { slow.toggle() } label: {
                        Label(slow ? "Normal speed" : "Slow motion", systemImage: slow ? "hare" : "tortoise")
                    }
                }
                .buttonStyle(.bordered)
                .font(.footnote.weight(.semibold))
                .tint(color)
            }
            Text("Orange shows the muscles doing the work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func still(_ exercise: Exercise, at point: Double, label: String) -> some View {
        VStack(spacing: 4) {
            ExerciseFigure(motion: exercise.motion, isPlaying: false, stillAt: point)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func header(name: String, muscles: String, equipment: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.display(28))
            FlowLayout(spacing: 6) {
                tag(muscles, symbol: "figure.arms.open")
                tag(equipment, symbol: "dumbbell")
            }
        }
    }

    private func tag(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Area.fitness.tint, in: Capsule())
            .foregroundStyle(color)
    }

    private func numbered(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(color, in: Circle())
                    Text(line).font(.subheadline)
                }
            }
        }
        .card()
    }

    private func bullets(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title)
            ForEach(lines, id: \.self) { line in
                Label(line, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .labelStyle(GuideBulletStyle())
            }
        }
        .card()
    }

    @ViewBuilder
    private var historyCard: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Your history")
                if let last = history.lastText, let date = history.lastDate {
                    ValueRow(label: "Last time", value: "\(last), \(DateText.countdown(date))")
                }
                if history.bestWeight > 0 {
                    ValueRow(label: "Heaviest", value: WeightText.kg(history.bestWeight))
                    ValueRow(label: "Estimated 1-rep max", value: WeightText.kg(history.bestEstimatedMax))
                } else if history.bestSeconds > 0 {
                    ValueRow(label: "Longest", value: DateText.clock(seconds: history.bestSeconds))
                } else {
                    ValueRow(label: "Most reps", value: "\(history.bestReps)")
                }
                NavigationLink(value: Route.progress(exerciseID)) {
                    Label("See progress", systemImage: "chart.line.uptrend.xyaxis").font(.subheadline.weight(.semibold))
                }
                .tint(color)
                .padding(.top, 4)
            }
            .card()
        }
    }

    @ViewBuilder
    private var addToWorkout: some View {
        if !templates.isEmpty {
            Menu {
                ForEach(templates) { template in
                    Button(template.name) { add(to: template) }
                }
            } label: {
                Label(addedTo.map { "Added to \($0)" } ?? "Add to a workout", systemImage: addedTo == nil ? "plus" : "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
        }
    }

    private func add(to template: WorkoutTemplate) {
        let order = (template.exercises ?? []).count
        let item: TemplateExercise
        if let exercise {
            item = ExerciseLibrary.templateExercise(for: exercise, sortOrder: order)
        } else {
            item = TemplateExercise(exerciseID: exerciseID, name: customExercise?.name ?? "Exercise", sortOrder: order)
        }
        context.insert(item)
        item.template = template
        addedTo = template.name
    }
}

private struct GuideBulletStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon.foregroundStyle(.orange).font(.caption)
            configuration.title
        }
    }
}
