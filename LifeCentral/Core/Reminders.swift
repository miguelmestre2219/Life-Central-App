import Foundation
import SwiftData
@preconcurrency import UserNotifications

/// Local notifications for bills, expiring documents and tasks with a time.
/// Rebuilt from the data whenever the app goes to the background, so edits
/// and deletions are always reflected.
final class Reminders {
    static let shared = Reminders()
    private let center = UNUserNotificationCenter.current()
    private let prefix = "lifecentral."

    func requestPermissionIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    @MainActor
    func reschedule(using context: ModelContext) {
        let bills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        let documents = (try? context.fetch(FetchDescriptor<Document>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isDone }))) ?? []

        var requests: [UNNotificationRequest] = []
        for bill in bills where !bill.isPaused {
            let fire = bill.nextDue.adding(days: -bill.remindDaysBefore)
            let body = "\(MoneyFormat.string(bill.amountMinor, bill.currencyCode)) due \(bill.nextDue.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
            if let request = makeRequest(id: "bill.\(bill.persistentModelID.hashValue)", title: bill.name, body: body, at: fire, hour: 9) {
                requests.append(request)
            }
        }
        for doc in documents {
            guard let expires = doc.expiresAt else { continue }
            let fire = expires.adding(days: -doc.remindDaysBefore)
            let body = "Expires \(expires.formatted(date: .long, time: .omitted)). Time to renew."
            if let request = makeRequest(id: "doc.\(doc.persistentModelID.hashValue)", title: doc.title, body: body, at: fire, hour: 10) {
                requests.append(request)
            }
        }
        for task in tasks where task.hasTime {
            guard let due = task.dueDate else { continue }
            if let request = makeRequest(id: "task.\(task.persistentModelID.hashValue)", title: task.title, body: "Now", at: due, hour: nil) {
                requests.append(request)
            }
        }

        // iOS keeps at most 64 pending notifications; the soonest matter most.
        let soonest = requests.sorted { Self.fireDate($0) < Self.fireDate($1) }.prefix(60)
        let center = self.center
        let prefix = self.prefix
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for request in soonest {
                center.add(request)
            }
        }
    }

    private static func fireDate(_ request: UNNotificationRequest) -> Date {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    private func makeRequest(id: String, title: String, body: String, at date: Date, hour: Int?) -> UNNotificationRequest? {
        var fireDate = date
        if let hour {
            fireDate = Calendar.app.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        }
        guard fireDate > .now else { return nil }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let parts = Calendar.app.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: prefix + id, content: content, trigger: trigger)
    }
}
