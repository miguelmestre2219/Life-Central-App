import SwiftUI
import SwiftData

struct WorkoutEditorView: View {
    @Bindable var template: WorkoutTemplate

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @State private var showPicker = false
    @State private var editing: TemplateExercise?
    @State private var confirmDelete = false
    @State private var showRename = false
    @State private var newName = ""

    private var color: Color { Color(hex: template.colorHex) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.kind.title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(color)
                    Text("\(template.orderedExercises.count) exercises · about \(template.estimatedMinutes) min")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let last = template.lastSession {
                        Text("Last done \(DateText.countdown(last.startedAt))").font(.footnote).foregroundStyle(.secondary)
                    }
                    HStack {
                        ForEach(Color.palette, id: \.self) { hex in
                            Button { template.colorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: template.colorHex == hex ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour")
                            .accessibilityAddTraits(template.colorHex == hex ? .isSelected : [])
                        }
                    }
                    .padding(.top, 4)
                }
                Button {
                    if router.liveSession == nil {
                        router.startWorkout(WorkoutCoach.start(template, in: context))
                    } else {
                        router.isLiveExpanded = true
                    }
                } label: {
                    Label(router.liveSession == nil ? "Start this workout" : "Open the workout in progress", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                ForEach(template.orderedExercises) { item in
                    Button { editing = item } label: {
                        HStack(spacing: 12) {
                            if let exercise = ExerciseLibrary.exercise(item.exerciseID) {
                                ExerciseFigure(motion: exercise.motion, isPlaying: false, stillAt: 0.5)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
                            } else {
                                IconChip(symbol: "dumbbell", color: color, size: 44)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).foregroundStyle(.primary)
                                Text(item.planText).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
                Button { showPicker = true } label: {
                    Label("Add exercises", systemImage: "plus")
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Weights fill in from last time when you start. Hold and drag to reorder.")
            }

            if let sessions = template.sessions, !sessions.filter(\.isFinished).isEmpty {
                Section("History") {
                    ForEach(sessions.filter(\.isFinished).sorted { $0.startedAt > $1.startedAt }.prefix(5)) { session in
                        NavigationLink(value: Route.session(session)) {
                            ValueRow(label: session.startedAt.formatted(date: .abbreviated, time: .omitted),
                                     value: "\(DateText.duration(minutes: session.durationMinutes)) · \(session.doneSets.count) sets")
                        }
                    }
                }
            }

            Section {
                ShareLink(item: shareText, subject: Text(template.name)) {
                    Label("Send to a friend", systemImage: "square.and.arrow.up")
                }
                Button("Delete workout", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("Past sessions stay in your history.")
            }
        }
        .tint(color)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename") {
                        newName = template.name
                        showRename = true
                    }
                    Picker("Type", selection: Binding(get: { template.kind }, set: { template.kind = $0 })) {
                        ForEach(WorkoutKind.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePicker(color: color) { picked in
                let start = (template.exercises ?? []).count
                for (offset, choice) in picked.enumerated() {
                    let item: TemplateExercise
                    if let exercise = ExerciseLibrary.exercise(choice.id) {
                        item = ExerciseLibrary.templateExercise(for: exercise, sortOrder: start + offset)
                    } else {
                        item = TemplateExercise(exerciseID: choice.id, name: choice.name, sortOrder: start + offset)
                    }
                    context.insert(item)
                    item.template = template
                }
            }
        }
        .sheet(item: $editing) { item in
            PlanEditor(item: item, color: color)
                .presentationDetents([.medium, .large])
        }
        .alert("Rename workout", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Save") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { template.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \(template.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                router.paths[.fitness] = []
                context.delete(template)
            }
        }
    }

    private var shareText: String {
        var lines = ["\(template.name) (Life Central workout)"]
        for item in template.orderedExercises {
            lines.append("• \(item.name): \(item.planText)")
        }
        return lines.joined(separator: "\n")
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = template.orderedExercises
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.sortOrder = index }
    }

    private func delete(at offsets: IndexSet) {
        let items = template.orderedExercises
        for index in offsets { context.delete(items[index]) }
    }
}

/// Sets, reps, weight and rest for one exercise in a workout.
struct PlanEditor: View {
    @Bindable var item: TemplateExercise
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @State private var showGuide = false

    private var exercise: Exercise? { ExerciseLibrary.exercise(item.exerciseID) }
    private var isTimed: Bool { item.durationSeconds > 0 || (exercise?.isTimed ?? false) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("\(item.sets) set\(item.sets == 1 ? "" : "s")", value: $item.sets, in: 1...12)
                    if isTimed {
                        Stepper("\(DateText.clock(seconds: item.durationSeconds)) each", value: $item.durationSeconds, in: 5...7200, step: item.durationSeconds >= 300 ? 60 : 5)
                    } else {
                        Stepper("\(item.reps) reps", value: $item.reps, in: 1...100)
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("0", value: $item.weightKg, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("kg").foregroundStyle(.secondary)
                        }
                    }
                    Stepper("Rest \(item.restSeconds >= 60 ? DateText.clock(seconds: item.restSeconds) : "\(item.restSeconds) s")",
                            value: $item.restSeconds, in: 0...600, step: 15)
                } footer: {
                    Text(isTimed ? "Timed exercise." : "Leave weight at 0 for body weight. When you start, it fills in from last time.")
                }
                if exercise != nil {
                    Section {
                        Button { showGuide = true } label: { Label("How to do it", systemImage: "figure.strengthtraining.traditional") }
                    }
                }
            }
            .tint(color)
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
            .navigationDestination(isPresented: $showGuide) {
                ExerciseGuideView(exerciseID: item.exerciseID)
            }
            .navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
    }
}
