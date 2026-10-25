import Foundation
import Observation
import UserNotifications

/// Rest timer between sets, and the countdown for timed sets (planks, holds).
/// Also schedules a notification so the end of a rest is noticed with the
/// phone locked.
@Observable
final class WorkoutTimer {
    enum Kind: Equatable {
        case rest
        case hold
    }

    private(set) var startDate: Date?
    private(set) var endDate: Date?
    private(set) var kind: Kind = .rest
    /// Goes up by one each time a countdown reaches zero.
    private(set) var finishedCount = 0
    private(set) var lastFinishedKind: Kind = .rest

    private var task: Task<Void, Never>?
    private static let notificationID = "rest.timer"

    var isRunning: Bool { endDate != nil }

    @MainActor
    func start(seconds: Int, kind: Kind, message: String) {
        cancel()
        guard seconds > 0 else { return }
        self.kind = kind
        let now = Date.now
        startDate = now
        endDate = now.addingTimeInterval(TimeInterval(seconds))
        schedule(seconds: seconds, message: message)
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.lastFinishedKind = self.kind
            self.startDate = nil
            self.endDate = nil
            self.finishedCount += 1
        }
    }

    /// Adds or removes time from the running countdown.
    @MainActor
    func adjust(by seconds: Int, message: String) {
        guard let endDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded()) + seconds
        let begin = startDate
        let currentKind = kind
        if remaining <= 0 {
            cancel()
            return
        }
        start(seconds: remaining, kind: currentKind, message: message)
        startDate = begin
    }

    @MainActor
    func cancel() {
        task?.cancel()
        task = nil
        startDate = nil
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func schedule(seconds: Int, message: String) {
        let content = UNMutableNotificationContent()
        content.title = kind == .rest ? "Rest over" : "Time"
        content.body = message
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
    }
}
