import SwiftUI
import SwiftData

/// Everything that wants your attention, newest first: bills, expiring
/// documents, overdue tasks, bookings still to make and things friends shared.
struct InboxView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Bill.nextDue) private var bills: [Bill]
    @Query private var documents: [Document]
    @Query(filter: #Predicate<TodoItem> { !$0.isDone }) private var tasks: [TodoItem]
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @Query(filter: #Predicate<WorkoutTemplate> { $0.sharedBy != "" }) private var sharedWorkouts: [WorkoutTemplate]

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let area: Area
        let title: String
        let detail: String
        let sortDate: Date
        let route: Route
    }

    private var items: [Item] {
        var result: [Item] = []
        for bill in bills where bill.isDueSoon {
            result.append(Item(id: "b\(bill.persistentModelID.hashValue)", symbol: BillGroup.icon(for: bill.group), area: .money,
                               title: "\(bill.name) is due \(DateText.countdown(bill.nextDue))",
                               detail: MoneyFormat.string(bill.amountMinor, bill.currencyCode), sortDate: bill.nextDue, route: .bills))
        }
        for doc in documents where doc.isExpiringSoon {
            guard let date = doc.expiresAt else { continue }
            result.append(Item(id: "d\(doc.persistentModelID.hashValue)", symbol: "exclamationmark.triangle", area: .documents,
                               title: "\(doc.title) expires \(date.formatted(date: .abbreviated, time: .omitted))",
                               detail: "Renew in good time", sortDate: date, route: .document(doc)))
        }
        for task in tasks where task.isOverdue {
            result.append(Item(id: "t\(task.persistentModelID.hashValue)", symbol: "calendar.badge.exclamationmark", area: .tasks,
                               title: task.title, detail: "Was due \(DateText.relativeDay(task.dueDate ?? .now))",
                               sortDate: task.dueDate ?? .now, route: .tasks))
        }
        for trip in trips where !trip.isPast && trip.startDate.daysFromToday <= 30 {
            for item in (trip.items ?? []) where item.booking == .toBook {
                result.append(Item(id: "i\(item.persistentModelID.hashValue)", symbol: "ticket", area: .travel,
                                   title: "Book \(item.title)", detail: "\(trip.name) · \(DateText.relativeDay(item.day))",
                                   sortDate: item.day, route: .tripDay(trip, item.day)))
            }
        }
        for workout in sharedWorkouts {
            result.append(Item(id: "w\(workout.persistentModelID.hashValue)", symbol: "person.2", area: .friends,
                               title: "\(workout.sharedBy) shared \(workout.name)", detail: "Now in your workouts",
                               sortDate: workout.createdAt, route: .workoutTemplate(workout)))
        }
        return result.sorted { $0.sortDate < $1.sortDate }
    }

    var body: some View {
        List {
            if items.isEmpty {
                EmptyState(symbol: "bell", title: "All clear", message: "Bills due soon, documents about to expire and bookings still to make will show here.")
                    .listRowBackground(Color.clear)
            }
            ForEach(items) { item in
                Button { router.show(item.route) } label: {
                    HStack(spacing: 12) {
                        IconChip(symbol: item.symbol, color: item.area.color, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Inbox")
    }
}
