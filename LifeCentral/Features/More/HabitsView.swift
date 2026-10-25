import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.sortOrder) private var habits: [Habit]

    private let color = Area.habits.color

    private var week: [Date] {
        let start = Date.now.startOfWeek
        return (0..<7).map { start.adding(days: $0) }
    }

    var body: some View {
        List {
            if habits.isEmpty {
                EmptyState(symbol: "checkmark.circle", title: "No habits yet",
                           message: "Small things you want to do most days. Tick them off and keep a streak going.",
                           actionTitle: "Add a habit", color: color) { router.present(.habit(nil)) }
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    let doneToday = habits.filter { $0.isDone(on: .now) }.count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(doneToday) of \(habits.count) done today").font(.headline)
                        ProgressBar(value: Double(doneToday) / Double(habits.count), color: color)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ForEach(habits) { habit in
                        HabitRow(habit: habit, week: week) { router.present(.habit(habit)) }
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Tap a day to tick it. Hold and drag to reorder.")
                }
            }
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.habit(nil)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add habit")
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = habits
        items.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in items.enumerated() { habit.sortOrder = index }
    }
}

struct HabitRow: View {
    let habit: Habit
    let week: [Date]
    let onEdit: () -> Void

    var body: some View {
        let color = Color(hex: habit.colorHex)
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onEdit) {
                HStack(spacing: 10) {
                    IconChip(symbol: habit.icon, color: color, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(habit.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(habit.linkedMetric == "water" ? "Ticks itself at 2 L of water · \(habit.streakText)" : habit.streakText)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if habit.streak >= 3 {
                        Label("\(habit.streak)", systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(week, id: \.self) { day in
                    let done = habit.isDone(on: day)
                    let isFuture = day > Date.now
                    Button { habit.toggle(on: day) } label: {
                        VStack(spacing: 4) {
                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(.secondary)
                            CircleTick(isOn: done, color: color, size: 28)
                                .overlay {
                                    if day.isToday && !done {
                                        Circle().strokeBorder(color, lineWidth: 2)
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                    .opacity(isFuture ? 0.35 : 1)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))): \(done ? "done" : "not done")")
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct HabitForm: View {
    let habit: Habit?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]

    @State private var name = ""
    @State private var icon = "checkmark.circle"
    @State private var colorHex = "6D28D9"
    @State private var target = 7
    @State private var detail = ""
    @State private var confirmDelete = false
    @State private var didLoad = false

    static let icons = ["checkmark.circle", "drop", "book", "figure.walk", "bed.double", "leaf", "brain.head.profile",
                        "pills", "fork.knife", "moon", "sun.max", "pencil", "music.note", "iphone.slash", "dumbbell", "heart"]
    static let suggestions = [("Read 10 pages", "book"), ("Walk 8,000 steps", "figure.walk"), ("Meditate", "brain.head.profile"),
                              ("Take vitamins", "pills"), ("In bed by 11", "bed.double"), ("No phone in the morning", "iphone.slash")]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit, e.g. Read 10 pages", text: $name)
                    if habit == nil && name.isEmpty {
                        FlowLayout {
                            ForEach(Self.suggestions, id: \.0) { suggestion in
                                ChoiceChip(title: suggestion.0, isOn: false) {
                                    name = suggestion.0
                                    icon = suggestion.1
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Stepper(target == 7 ? "Every day" : "\(target) days a week", value: $target, in: 1...7)
                    TextField("Note (optional)", text: $detail)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .frame(width: 34, height: 34)
                                    .foregroundStyle(icon == symbol ? .white : Color(hex: colorHex))
                                    .background(icon == symbol ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Colour") {
                    HStack {
                        ForEach(Color.palette, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: colorHex == hex ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let habit {
                    Section {
                        Button("Archive habit") {
                            habit.isArchived = true
                            dismiss()
                        }
                        Button("Delete habit", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("Archiving hides it but keeps its history.")
                    }
                }
            }
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete \(name) and its history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let habit { context.delete(habit) }
                    dismiss()
                }
            }
        }
    }

    private func load() {
        guard !didLoad, let habit else { return }
        didLoad = true
        name = habit.name
        icon = habit.icon
        colorHex = habit.colorHex
        target = habit.targetPerWeek
        detail = habit.detail
    }

    private func save() {
        let item: Habit
        if let habit {
            item = habit
        } else {
            item = Habit(name: name)
            item.sortOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
            context.insert(item)
        }
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.icon = icon
        item.colorHex = colorHex
        item.targetPerWeek = target
        item.detail = detail
        dismiss()
    }
}
