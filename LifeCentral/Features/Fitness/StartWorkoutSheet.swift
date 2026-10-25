import SwiftUI
import SwiftData

/// "Start workout" from the + button, Today or Fitness.
struct StartWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            List {
                if let live = router.liveSession {
                    Section {
                        Button {
                            dismiss()
                            router.isLiveExpanded = true
                        } label: {
                            Label("Continue \(live.name)", systemImage: "play.circle.fill")
                                .font(.headline)
                        }
                    } footer: {
                        Text("Finish this workout before starting another.")
                    }
                }

                Section("Your workouts") {
                    ForEach(templates) { template in
                        Button { start(template) } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color(hex: template.colorHex)).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                    Text("\(template.orderedExercises.count) exercises · ~\(template.estimatedMinutes) min"
                                         + (template.lastSession.map { " · last \(DateText.countdown($0.startedAt))" } ?? ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.fill").foregroundStyle(Color(hex: template.colorHex))
                            }
                        }
                        .disabled(router.liveSession != nil)
                    }
                    Button { start(nil) } label: {
                        Label("Empty workout, add exercises as you go", systemImage: "plus.circle")
                    }
                    .disabled(router.liveSession != nil)
                }
            }
            .tint(Area.fitness.color)
            .navigationTitle("Start workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("New workout") { router.present(.newWorkout) }
                }
            }
        }
    }

    private func start(_ template: WorkoutTemplate?) {
        let session = WorkoutCoach.start(template, in: context)
        dismiss()
        router.startWorkout(session)
    }
}

/// Creates a workout for the library, blank or from a ready-made plan.
struct NewWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query private var templates: [WorkoutTemplate]

    @State private var name = ""
    @State private var colorHex = "C2410C"
    @State private var kind: WorkoutKind = .strength

    /// Ready-made workouts: name, colour, kind, exercise ids.
    static let starters: [(name: String, color: String, kind: WorkoutKind, exercises: [String])] = [
        ("Full body", "C2410C", .strength, ["goblet-squat", "dumbbell-bench-press", "seated-cable-row", "romanian-deadlift", "plank"]),
        ("Upper body", "1D4ED8", .strength, ["bench-press", "lat-pulldown", "dumbbell-shoulder-press", "barbell-row", "bicep-curl", "tricep-pushdown"]),
        ("Lower body", "047857", .strength, ["squat", "romanian-deadlift", "walking-lunge", "leg-curl", "calf-raise"]),
        ("Glutes and core", "BE185D", .strength, ["hip-thrust", "bulgarian-split-squat", "kettlebell-swing", "hanging-leg-raise", "plank"]),
        ("No-equipment circuit", "6D28D9", .strength, ["jumping-jack", "push-up", "glute-bridge", "mountain-climber", "crunch"]),
        ("Cardio", "0E7490", .cardio, ["rowing-machine", "cycling", "running"]),
        ("Stretch and mobility", "334155", .mobility, ["hamstring-stretch", "hip-flexor-stretch"]),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Push day", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(WorkoutKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        ForEach(Color.palette, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: colorHex == hex ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour")
                            .accessibilityAddTraits(colorHex == hex ? .isSelected : [])
                        }
                    }
                } footer: {
                    Text("You'll add exercises on the next screen.")
                }

                Section("Or start from a ready-made workout") {
                    ForEach(Self.starters, id: \.name) { starter in
                        Button { create(starter) } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color(hex: starter.color)).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(starter.name).foregroundStyle(.primary)
                                    Text(starter.exercises.compactMap { ExerciseLibrary.exercise($0)?.name }.joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
            .tint(Area.fitness.color)
            .navigationTitle("New workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create(nil) }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func create(_ starter: (name: String, color: String, kind: WorkoutKind, exercises: [String])?) {
        let template = WorkoutTemplate(name: starter?.name ?? name.trimmingCharacters(in: .whitespaces),
                                       colorHex: starter?.color ?? colorHex, kind: starter?.kind ?? kind)
        template.sortOrder = (templates.map(\.sortOrder).max() ?? -1) + 1
        context.insert(template)
        for (index, id) in (starter?.exercises ?? []).enumerated() {
            guard let exercise = ExerciseLibrary.exercise(id) else { continue }
            let item = ExerciseLibrary.templateExercise(for: exercise, sortOrder: index)
            context.insert(item)
            item.template = template
        }
        dismiss()
        router.show(.workoutTemplate(template))
    }
}
