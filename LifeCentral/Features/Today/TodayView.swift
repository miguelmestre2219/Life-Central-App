import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HealthService.self) private var health
    @Environment(\.modelContext) private var context

    @Query(sort: \Bill.nextDue) private var bills: [Bill]
    @Query(sort: \Document.title) private var documents: [Document]
    @Query(filter: #Predicate<TodoItem> { !$0.isDone }, sort: \TodoItem.createdAt) private var openTasks: [TodoItem]
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var entries: [MoneyEntry]
    @Query private var categories: [MoneyCategory]
    @Query private var meals: [MealPlanEntry]

    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !attention.isEmpty { attentionSection }
                timelineSection
                glanceSection
                if !habits.isEmpty { habitsSection }
                Spacer(minLength: 70)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
        }
        .screenBackground()
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(title: "Add", color: .primary) { router.present(.quickAdd) }
                .padding(.trailing, Theme.gutter)
                .padding(.bottom, 12)
                .accessibilityHint("Add money, a bill, a task, a document and more")
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await health.refreshToday() }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.app.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        return userName.isEmpty ? part : "\(part), \(userName)"
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(greeting)
                    .font(.display(28))
            }
            Spacer()
            HStack(spacing: 8) {
                circleButton("magnifyingglass", label: "Search") { router.push(.search) }
                circleButton("bell", label: "Inbox, \(inboxCount) new", badge: inboxCount) { router.push(.inbox) }
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ symbol: String, label: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Color.red, in: Capsule())
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Needs attention

    private struct AttentionItem: Identifiable {
        let id: String
        let title: String
        let detail: String
        let route: Route
    }

    private var attention: [AttentionItem] {
        var items: [AttentionItem] = []
        for bill in bills where bill.isDueSoon {
            let when = DateText.countdown(bill.nextDue)
            items.append(AttentionItem(id: "bill-\(bill.persistentModelID.hashValue)", title: bill.name,
                                       detail: "due \(when) · \(MoneyFormat.string(bill.amountMinor, bill.currencyCode))", route: .bills))
        }
        for doc in documents where doc.isExpiringSoon {
            guard let expires = doc.expiresAt else { continue }
            let tripClash = trips.first { !$0.isPast && $0.endDate >= expires }
            let detail = tripClash.map { "expires before your \($0.name) trip" } ?? "expires \(DateText.countdown(expires))"
            items.append(AttentionItem(id: "doc-\(doc.persistentModelID.hashValue)", title: doc.title, detail: detail, route: .document(doc)))
        }
        let overdue = openTasks.filter(\.isOverdue)
        if !overdue.isEmpty {
            items.append(AttentionItem(id: "tasks", title: overdue.count == 1 ? overdue[0].title : "\(overdue.count) tasks",
                                       detail: "overdue", route: .tasks))
        }
        return items
    }

    private var inboxCount: Int { attention.count }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Needs attention")
            VStack(spacing: 0) {
                ForEach(attention) { item in
                    Button { router.show(item.route) } label: {
                        HStack {
                            (Text(item.title).bold() + Text(" \(item.detail)"))
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color(hex: "78350F"))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                    }
                    .buttonStyle(.plain)
                    if item.id != attention.last?.id { Divider().padding(.leading, 14) }
                }
            }
            .background(Color(hex: "FEF3C7"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Today timeline

    private struct TimelineItem: Identifiable {
        let id: String
        let time: Date?
        let title: String
        let detail: String
        let color: Color
        let action: Action

        enum Action { case route(Route), startWorkout }
    }

    private var timeline: [TimelineItem] {
        var items: [TimelineItem] = []
        for task in openTasks where task.isDueToday {
            items.append(TimelineItem(id: "task-\(task.persistentModelID.hashValue)", time: task.hasTime ? task.dueDate : nil,
                                      title: task.title, detail: "Task", color: Area.tasks.color, action: .route(.tasks)))
        }
        for bill in bills where !bill.isPaused && bill.nextDue.isToday {
            items.append(TimelineItem(id: "bill-\(bill.persistentModelID.hashValue)", time: nil, title: bill.name,
                                      detail: MoneyFormat.string(bill.amountMinor, bill.currencyCode), color: Area.money.color, action: .route(.bills)))
        }
        if let trip = trips.first(where: \.isUnderway) {
            for item in trip.items(on: .now) {
                items.append(TimelineItem(id: "trip-\(item.persistentModelID.hashValue)", time: item.startTime, title: item.title,
                                          detail: trip.name, color: Area.travel.color, action: .route(.tripDay(trip, Date.now.startOfDay))))
            }
        }
        for meal in meals where meal.day.isToday {
            items.append(TimelineItem(id: "meal-\(meal.persistentModelID.hashValue)", time: nil, title: meal.name,
                                      detail: meal.slot.title, color: Area.meals.color, action: .route(.meals)))
        }
        return items.sorted { a, b in
            switch (a.time, b.time) {
            case let (x?, y?): x < y
            case (_?, nil): true
            default: false
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: "Today")
                Button("Full day") { router.show(.tasks) }
                    .font(.footnote.weight(.semibold))
            }
            VStack(spacing: 0) {
                if router.liveSession == nil {
                    Button { router.present(.startWorkout) } label: {
                        timelineRow(time: "GYM?", title: "Start a workout", detail: lastWorkoutText, color: Area.fitness.color, trailing: "Start")
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 14)
                }
                if timeline.isEmpty {
                    Text("Nothing else planned. Tap Add to put something on today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(timeline) { item in
                    Button {
                        if case .route(let route) = item.action { router.show(route) }
                    } label: {
                        timelineRow(time: item.time.map(DateText.time) ?? "All day", title: item.title, detail: item.detail, color: item.color, trailing: nil)
                    }
                    .buttonStyle(.plain)
                    if item.id != timeline.last?.id { Divider().padding(.leading, 14) }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private var lastWorkoutText: String {
        guard let last = sessions.first(where: \.isFinished) else { return "Pick one from your library" }
        return "Last: \(last.name), \(DateText.countdown(last.startedAt))"
    }

    private func timelineRow(time: String, title: String, detail: String, color: Color, trailing: String?) -> some View {
        HStack(spacing: 12) {
            Text(time)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body.weight(.semibold)).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(color, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    // MARK: At a glance

    private var glanceSection: some View {
        let summary = MoneySummary(entries: entries, categories: categories, bills: bills.filter { !$0.isPaused }, month: .now)
        let nextTrip = trips.first { !$0.isPast }
        let weekStart = Date.now.startOfWeek
        let workoutsThisWeek = sessions.filter { $0.isFinished && $0.startedAt >= weekStart }.count
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "At a glance")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                glanceTile("MONEY", summary.planned > 0 ? "\(MoneyFormat.string(summary.leftToSpend, home, whole: true)) left" : MoneyFormat.string(summary.spent, home, whole: true) + " spent",
                           color: Area.money.color) { router.tab = .money }
                glanceTile("NEXT TRIP", nextTrip.map { "\($0.destination.isEmpty ? $0.name : $0.destination) · \(max(0, $0.startDate.daysFromToday)) days" } ?? "Plan one",
                           color: Area.travel.color) {
                    if let nextTrip { router.show(.trip(nextTrip)) } else { router.tab = .travel }
                }
                glanceTile("WORKOUTS", "\(workoutsThisWeek) this week", color: Area.fitness.color) { router.tab = .fitness }
                glanceTile("HEALTH", health.stepsToday.map { "\(Int($0).formatted()) steps" } ?? "Connect", color: Area.health.color) { router.show(.health) }
            }
        }
    }

    private func glanceTile(_ label: String, _ value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                Text(label).font(.caption2.weight(.bold)).foregroundStyle(color)
                Spacer(minLength: 6)
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Habits

    private var habitsSection: some View {
        let done = habits.filter { $0.isDone(on: .now) }.count
        return VStack(alignment: .leading, spacing: 6) {
            Button { router.show(.habits) } label: {
                HStack {
                    Text("HABITS \(done)/\(habits.count)").font(.caption.weight(.bold)).foregroundStyle(Area.habits.color)
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(Area.habits.color)
                }
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(habits) { habit in
                        let isDone = habit.isDone(on: .now)
                        Button {
                            withAnimation { habit.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                CircleTick(isOn: isDone, color: Area.habits.color, size: 20)
                                Text(habit.name).font(.subheadline).lineLimit(1)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(Theme.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(habit.name), \(isDone ? "done" : "not done")")
                    }
                }
                .padding(.trailing, 96)
            }
        }
    }
}
