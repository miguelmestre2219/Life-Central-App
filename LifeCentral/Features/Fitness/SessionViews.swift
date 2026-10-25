import SwiftUI
import SwiftData

/// Shown when you tap Finish: a summary, how it felt, and where to save it.
struct FinishWorkoutSheet: View {
    @Bindable var session: WorkoutSession
    let records: Int
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(HealthService.self) private var health
    @State private var saveToHealth = true
    @State private var updatePlan = true

    private var color: Color { Color(hex: session.colorHex) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        summary(DateText.duration(minutes: session.durationMinutes), "time")
                        summary("\(session.doneSets.count)", "sets")
                        summary(WeightText.kg(session.volumeKg), "lifted")
                        if records > 0 { summary("\(records)", records == 1 ? "record" : "records") }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }

                Section("How did it feel?") {
                    HStack(spacing: 6) {
                        ForEach(Array(WorkoutSession.feelings.enumerated()), id: \.offset) { index, title in
                            ChoiceChip(title: title, isOn: session.feeling == index + 1, color: color) {
                                session.feeling = session.feeling == index + 1 ? 0 : index + 1
                            }
                        }
                    }
                    TextField("Notes (optional)", text: $session.note, axis: .vertical)
                }

                Section {
                    if health.isAvailable {
                        Toggle("Save to Apple Health", isOn: $saveToHealth)
                    }
                    if session.template != nil {
                        Toggle("Use today's weights next time", isOn: $updatePlan)
                    }
                } footer: {
                    if session.doneSets.isEmpty {
                        Text("No sets are ticked yet. Finishing now saves an empty workout.")
                    }
                }
            }
            .tint(color)
            .navigationTitle("Finish workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Keep going") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func summary(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        if updatePlan { WorkoutCoach.updatePlan(from: session) }
        let wantsHealth = saveToHealth && health.isAvailable
        dismiss()
        onSave()
        if wantsHealth {
            let target = session
            Task {
                if await health.saveWorkout(target) { target.savedToHealth = true }
            }
        }
    }
}

/// The small bar above the tab bar while a workout is minimised.
struct LiveWorkoutBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let session = router.liveSession, !router.isLiveExpanded {
            let groups = session.exerciseGroups
            let current = groups.indices.contains(session.currentExerciseIndex) ? groups[session.currentExerciseIndex].name : nil
            Button { router.isLiveExpanded = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: session.colorHex), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.name).font(.subheadline.weight(.semibold))
                        Text(current ?? "Add an exercise").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(session.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                    Image(systemName: "chevron.up").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .accessibilityLabel("Workout in progress: \(session.name). Open.")
        }
    }
}

struct SessionDetailView: View {
    @Bindable var session: WorkoutSession

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(HealthService.self) private var health
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var isSavingToHealth = false

    private var color: Color { Color(hex: session.colorHex) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        stat(DateText.duration(minutes: session.durationMinutes), "time")
                        stat("\(session.doneSets.count)", "sets")
                        stat(WeightText.kg(session.volumeKg), "lifted")
                    }
                    if session.feeling > 0 {
                        Text("Felt: \(WorkoutSession.feelings[session.feeling - 1])").font(.footnote.weight(.semibold)).foregroundStyle(color)
                    }
                }
                .padding(.vertical, 4)
            }

            ForEach(session.exerciseGroups, id: \.order) { group in
                Section {
                    ForEach(group.sets.filter(\.isDone)) { set in
                        HStack {
                            Text("Set \(set.setIndex + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text(setText(set)).monospacedDigit()
                        }
                    }
                } header: {
                    if ExerciseLibrary.exercise(group.id) != nil {
                        NavigationLink(value: Route.progress(group.id)) {
                            HStack {
                                Text(group.name)
                                Image(systemName: "chart.line.uptrend.xyaxis")
                            }
                        }
                    } else {
                        Text(group.name)
                    }
                }
            }

            Section("Notes") {
                TextField("How it went", text: $session.note, axis: .vertical)
            }

            Section {
                if let template = session.template {
                    Button {
                        if router.liveSession == nil {
                            router.startWorkout(WorkoutCoach.start(template, in: context))
                        } else {
                            router.isLiveExpanded = true
                        }
                    } label: {
                        Label("Do \(template.name) again", systemImage: "arrow.clockwise")
                    }
                }
                if health.isAvailable {
                    if session.savedToHealth {
                        Label("Saved to Apple Health", systemImage: "checkmark.circle.fill").foregroundStyle(Area.health.color)
                    } else {
                        Button {
                            isSavingToHealth = true
                            Task {
                                if await health.saveWorkout(session) { session.savedToHealth = true }
                                isSavingToHealth = false
                            }
                        } label: {
                            Label(isSavingToHealth ? "Saving…" : "Save to Apple Health", systemImage: "heart")
                        }
                        .disabled(isSavingToHealth)
                    }
                }
                Button("Delete workout", role: .destructive) { confirmDelete = true }
            }
        }
        .tint(color)
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this workout from your history?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                let doomed = session
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { context.delete(doomed) }
            }
        } message: {
            Text(session.savedToHealth ? "The copy in Apple Health stays." : "This can't be undone.")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func setText(_ set: SessionSet) -> String {
        if set.durationSeconds > 0 { return DateText.clock(seconds: set.durationSeconds) }
        if set.weightKg > 0 { return "\(WeightText.kg(set.weightKg)) × \(set.reps)" }
        return "\(set.reps) reps"
    }
}
