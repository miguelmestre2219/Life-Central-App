import Foundation
import SwiftData

// Every stored property has a default and every relationship is optional so the
// same store can later sync through iCloud (CloudKit needs both).

@Model
final class MoneyCategory {
    var name: String = ""
    var icon: String = "tag"
    var colorHex: String = "047857"
    var isIncome: Bool = false
    /// Planned spend per month in the home currency. A month can override it.
    var monthlyPlanMinor: Int = 0
    var sortOrder: Int = 0
    var isArchived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \MoneyEntry.category)
    var entries: [MoneyEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \Bill.category)
    var bills: [Bill]? = []
    @Relationship(deleteRule: .cascade, inverse: \PlanOverride.category)
    var overrides: [PlanOverride]? = []

    init(name: String, icon: String, colorHex: String = "047857", isIncome: Bool = false, monthlyPlanMinor: Int = 0, sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isIncome = isIncome
        self.monthlyPlanMinor = monthlyPlanMinor
        self.sortOrder = sortOrder
    }

    func plan(for month: Date) -> Int {
        overrides?.first { $0.monthKey == month.monthKey }?.amountMinor ?? monthlyPlanMinor
    }

    func setPlan(_ amount: Int, for month: Date, everyMonth: Bool, in context: ModelContext) {
        if everyMonth {
            monthlyPlanMinor = amount
            for override in overrides ?? [] where override.monthKey >= month.monthKey {
                context.delete(override)
            }
        } else if let existing = overrides?.first(where: { $0.monthKey == month.monthKey }) {
            existing.amountMinor = amount
        } else {
            let override = PlanOverride(monthKey: month.monthKey, amountMinor: amount)
            context.insert(override)
            override.category = self
        }
    }

    /// Spent (or received) in the home currency during the month of `month`.
    func total(in month: Date) -> Int {
        let key = month.monthKey
        return (entries ?? []).filter { $0.date.monthKey == key }.reduce(0) { $0 + $1.homeAmountMinor }
    }
}

@Model
final class PlanOverride {
    var monthKey: Int = 0
    var amountMinor: Int = 0
    var category: MoneyCategory?

    init(monthKey: Int, amountMinor: Int) {
        self.monthKey = monthKey
        self.amountMinor = amountMinor
    }
}

enum RepeatRule: String, CaseIterable, Identifiable {
    case never, weekly, monthly, yearly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .never: "Never"
        case .weekly: "Every week"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }
}

@Model
final class MoneyEntry {
    var date: Date = Date.now
    var isIncome: Bool = false
    /// In the currency it was paid in.
    var amountMinor: Int = 0
    var currencyCode: String = "GBP"
    /// Home-currency units per one unit of `currencyCode`, frozen when saved.
    var rateToHome: Double = 1
    var homeCurrencyCode: String = "GBP"
    var homeAmountMinor: Int = 0
    var note: String = ""
    var paidWith: String = ""
    var repeatRaw: String = RepeatRule.never.rawValue
    @Attribute(.externalStorage) var receipt: Data?
    var createdAt: Date = Date.now

    var category: MoneyCategory?
    var trip: Trip?
    var bill: Bill?
    var tripItem: TripItem?

    init(date: Date = .now, isIncome: Bool = false, amountMinor: Int, currencyCode: String, rateToHome: Double, note: String = "") {
        self.date = date
        self.isIncome = isIncome
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.rateToHome = rateToHome
        self.note = note
        self.homeCurrencyCode = AppSettings.homeCurrency
        self.homeAmountMinor = MoneyFormat.convert(amountMinor, from: currencyCode, to: AppSettings.homeCurrency, rate: rateToHome)
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRaw) ?? .never }
        set { repeatRaw = newValue.rawValue }
    }

    /// Recalculates the home amount after the amount, currency or rate change.
    func updateHomeAmount() {
        homeCurrencyCode = AppSettings.homeCurrency
        homeAmountMinor = MoneyFormat.convert(amountMinor, from: currencyCode, to: homeCurrencyCode, rate: rateToHome)
    }

    var title: String {
        if !note.isEmpty { return note }
        return category?.name ?? (isIncome ? "Income" : "Spending")
    }

    var isForeign: Bool { currencyCode != homeCurrencyCode }
}

enum BillFrequency: String, CaseIterable, Identifiable {
    case weekly, monthly, quarterly, yearly, once
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Every 3 months"
        case .yearly: "Yearly"
        case .once: "Once"
        }
    }
    var short: String {
        switch self {
        case .weekly: "/wk"
        case .monthly: "/mo"
        case .quarterly: "/qtr"
        case .yearly: "/yr"
        case .once: ""
        }
    }
    /// How much of one payment falls in an average month.
    var monthlyFactor: Double {
        switch self {
        case .weekly: 52.0 / 12.0
        case .monthly: 1
        case .quarterly: 1.0 / 3.0
        case .yearly: 1.0 / 12.0
        case .once: 0
        }
    }

    func next(after date: Date) -> Date {
        switch self {
        case .weekly: date.adding(days: 7)
        case .monthly: date.adding(months: 1)
        case .quarterly: date.adding(months: 3)
        case .yearly: date.adding(months: 12)
        case .once: date
        }
    }
}

/// Default groups; people can type their own.
enum BillGroup {
    static let defaults = ["Home", "Car", "Subscriptions", "Insurance", "Phone and internet", "Other"]

    static func icon(for group: String) -> String {
        switch group {
        case "Home": "house"
        case "Car": "car"
        case "Subscriptions": "play.rectangle"
        case "Insurance": "shield"
        case "Phone and internet": "wifi"
        default: "doc.plaintext"
        }
    }
}

@Model
final class Bill {
    var name: String = ""
    var amountMinor: Int = 0
    var currencyCode: String = "GBP"
    var frequencyRaw: String = BillFrequency.monthly.rawValue
    var group: String = "Home"
    var nextDue: Date = Date.now
    var remindDaysBefore: Int = 3
    var countInPlan: Bool = true
    var isPaused: Bool = false
    var paidFrom: String = ""
    var notes: String = ""
    var createdAt: Date = Date.now

    var category: MoneyCategory?
    @Relationship(deleteRule: .nullify, inverse: \MoneyEntry.bill)
    var payments: [MoneyEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \Document.bill)
    var documents: [Document]? = []

    init(name: String, amountMinor: Int, currencyCode: String, frequency: BillFrequency, group: String, nextDue: Date) {
        self.name = name
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.frequencyRaw = frequency.rawValue
        self.group = group
        self.nextDue = nextDue
    }

    var frequency: BillFrequency {
        get { BillFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Average monthly cost in the home currency.
    var monthlyHomeMinor: Int {
        guard !isPaused else { return 0 }
        let rate = ExchangeRates.shared.rate(from: currencyCode, to: AppSettings.homeCurrency) ?? 1
        let home = MoneyFormat.convert(amountMinor, from: currencyCode, to: AppSettings.homeCurrency, rate: rate)
        return Int((Double(home) * frequency.monthlyFactor).rounded())
    }

    var isDueSoon: Bool {
        !isPaused && nextDue.daysFromToday <= remindDaysBefore
    }

    /// Records a payment in Money and moves the due date on.
    @MainActor
    func markPaid(in context: ModelContext) {
        let rate = ExchangeRates.shared.rate(from: currencyCode, to: AppSettings.homeCurrency) ?? 1
        let entry = MoneyEntry(date: .now, amountMinor: amountMinor, currencyCode: currencyCode, rateToHome: rate, note: name)
        context.insert(entry)
        entry.category = category
        entry.bill = self
        entry.paidWith = paidFrom
        if frequency == .once {
            isPaused = true
        } else {
            var due = nextDue
            repeat { due = frequency.next(after: due) } while due < Date.now.startOfDay
            nextDue = due
        }
    }
}
