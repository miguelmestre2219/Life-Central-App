import Foundation

extension Calendar {
    /// The user's calendar with their chosen first day of the week.
    static var app: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = AppSettings.weekStartsMonday ? 2 : 1
        return calendar
    }
}

extension Date {
    var startOfDay: Date { Calendar.app.startOfDay(for: self) }

    var startOfMonth: Date {
        Calendar.app.date(from: Calendar.app.dateComponents([.year, .month], from: self)) ?? self
    }

    var startOfWeek: Date {
        Calendar.app.dateInterval(of: .weekOfYear, for: self)?.start ?? startOfDay
    }

    /// 202610 for October 2026. Used to key monthly plans.
    var monthKey: Int {
        let parts = Calendar.app.dateComponents([.year, .month], from: self)
        return (parts.year ?? 0) * 100 + (parts.month ?? 0)
    }

    func adding(days: Int) -> Date {
        Calendar.app.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(months: Int) -> Date {
        Calendar.app.date(byAdding: .month, value: months, to: self) ?? self
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.app.isDate(self, inSameDayAs: other)
    }

    var isToday: Bool { Calendar.app.isDateInToday(self) }

    /// Whole days from today to this date (negative when in the past).
    var daysFromToday: Int {
        Calendar.app.dateComponents([.day], from: Date.now.startOfDay, to: startOfDay).day ?? 0
    }

    /// Every day from this date to `end`, inclusive.
    func days(through end: Date) -> [Date] {
        var result: [Date] = []
        var day = startOfDay
        let last = end.startOfDay
        while day <= last && result.count < 400 {
            result.append(day)
            day = day.adding(days: 1)
        }
        return result
    }

    /// Combines this date's day with the clock time of `time`.
    func at(timeOf time: Date) -> Date {
        let clock = Calendar.app.dateComponents([.hour, .minute], from: time)
        return Calendar.app.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0, of: self) ?? self
    }
}

enum DateText {
    /// "Today", "Tomorrow", "Yesterday", or "Sat 8 Nov".
    static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.app
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "in 12 days", "tomorrow", "3 days ago".
    static func countdown(_ date: Date) -> String {
        let days = date.daysFromToday
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case let d where d > 1: return "in \(d) days"
        default: return "\(-days) days ago"
        }
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "6 – 10 Nov" or "28 Dec – 3 Jan".
    static func range(_ start: Date, _ end: Date) -> String {
        let sameMonth = Calendar.app.isDate(start, equalTo: end, toGranularity: .month)
        let startText = sameMonth
            ? start.formatted(.dateTime.day())
            : start.formatted(.dateTime.day().month(.abbreviated))
        return "\(startText) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
    }

    static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    static func clock(seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
