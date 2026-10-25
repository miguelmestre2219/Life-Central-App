import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt) private var tasks: [TodoItem]
    @State private var newTitle = ""
    @State private var showDone = false
    @FocusState private var isAdding: Bool

    private let color = Area.tasks.color

    private var open: [TodoItem] { tasks.filter { !$0.isDone } }
    private var overdue: [TodoItem] { open.filter(\.isOverdue).sorted(by: Self.byDue) }
    private var today: [TodoItem] { open.filter { $0.isDueToday }.sorted(by: Self.byDue) }
    private var upcoming: [TodoItem] { open.filter { $0.dueDate.map { $0.startOfDay > Date.now.startOfDay } ?? false }.sorted(by: Self.byDue) }
    private var someday: [TodoItem] { open.filter { $0.dueDate == nil } }
    private var done: [TodoItem] { tasks.filter(\.isDone).sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) } }

    static func byDue(_ a: TodoItem, _ b: TodoItem) -> Bool {
        (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(color).font(.title3)
                    TextField("Add a task for today", text: $newTitle)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(quickAdd)
                }
            } footer: {
                Text("Tap a task to add a date, time or trip.")
            }

            group("Overdue", overdue, tint: .orange)
            group("Today", today)
            group("Coming up", upcoming)
            group("Someday", someday)

            if !done.isEmpty {
                Section {
                    DisclosureGroup("Done (\(done.count))", isExpanded: $showDone) {
                        ForEach(done.prefix(30)) { task in row(task) }
                        Button("Clear done tasks", role: .destructive) {
                            for task in done { context.delete(task) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.task(nil)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New task")
            }
        }
        .overlay {
            if tasks.isEmpty {
                EmptyState(symbol: "checklist", title: "Nothing to do", message: "Add tasks with a date and time to get a reminder.",
                           actionTitle: "New task", color: color) { router.present(.task(nil)) }
                    .padding(.top, 120)
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [TodoItem], tint: Color = .secondary) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { row($0) }
                    .onDelete { offsets in for i in offsets { context.delete(items[i]) } }
            } header: {
                Text(title).foregroundStyle(tint)
            }
        }
    }

    private func row(_ task: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    task.isDone.toggle()
                    task.doneAt = task.isDone ? .now : nil
                }
            } label: { CircleTick(isOn: task.isDone, color: color, size: 24) }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")

            Button { router.present(.task(task)) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                    let detail = detailText(task)
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(task.isOverdue ? .orange : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func detailText(_ task: TodoItem) -> String {
        var parts: [String] = []
        if let due = task.dueDate {
            parts.append(task.hasTime ? "\(DateText.relativeDay(due)), \(DateText.time(due))" : DateText.relativeDay(due))
        }
        if let trip = task.trip { parts.append(trip.name) }
        if !task.notes.isEmpty { parts.append(task.notes) }
        return parts.joined(separator: " · ")
    }

    private func quickAdd() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        context.insert(TodoItem(title: title, dueDate: Date.now.startOfDay))
        newTitle = ""
        isAdding = true
    }
}

struct TaskForm: View {
    let task: TodoItem?
    var presetTrip: Trip?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDate = true
    @State private var date = Date.now
    @State private var hasTime = false
    @State private var trip: Trip?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                Section {
                    Toggle("Date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Day", selection: $date, displayedComponents: .date)
                        Toggle("Time", isOn: $hasTime)
                        if hasTime {
                            DatePicker("At", selection: $date, displayedComponents: .hourAndMinute)
                        }
                    }
                } footer: {
                    if hasDate && hasTime { Text("You'll get a reminder at this time.") }
                }
                Section {
                    Picker("Trip", selection: $trip) {
                        Text("None").tag(Trip?.none)
                        ForEach(trips.filter { !$0.isPast || $0 === trip }) { Text($0.name).tag(Trip?.some($0)) }
                    }
                } footer: {
                    Text("Tasks linked to a trip show on the trip page under Before you go.")
                }
                if let task {
                    Section {
                        Button("Delete task", role: .destructive) {
                            context.delete(task)
                            dismiss()
                        }
                    }
                }
            }
            .tint(Area.tasks.color)
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        trip = presetTrip
        if let presetTrip, task == nil {
            // Trip to-dos default to a few days before leaving.
            date = max(Date.now, presetTrip.startDate.adding(days: -3))
        }
        guard let task else { return }
        title = task.title
        notes = task.notes
        hasDate = task.dueDate != nil
        date = task.dueDate ?? .now
        hasTime = task.hasTime
        trip = task.trip
    }

    private func save() {
        let item: TodoItem
        if let task {
            item = task
        } else {
            item = TodoItem(title: title)
            context.insert(item)
        }
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.notes = notes
        item.dueDate = hasDate ? (hasTime ? date : date.startOfDay) : nil
        item.hasTime = hasDate && hasTime
        item.trip = trip
        dismiss()
    }
}
