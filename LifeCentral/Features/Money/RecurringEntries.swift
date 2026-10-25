import Foundation
import SwiftData

/// Creates the next copy of repeating entries (salary, rent paid by hand…)
/// once its date arrives. The newest copy carries the repeat rule forward,
/// so each entry only ever produces one follow-up.
enum RecurringEntries {
    @MainActor
    static func generate(in context: ModelContext) {
        let never = RepeatRule.never.rawValue
        let descriptor = FetchDescriptor<MoneyEntry>(predicate: #Predicate { $0.repeatRaw != never })
        guard let repeating = try? context.fetch(descriptor) else { return }
        let today = Date.now.startOfDay
        for original in repeating {
            var source = original
            // Catch up on every missed occurrence, at most a year's worth.
            for _ in 0..<53 {
                guard let next = nextDate(after: source.date, rule: source.repeatRule), next.startOfDay <= today else { break }
                let copy = MoneyEntry(date: next, isIncome: source.isIncome, amountMinor: source.amountMinor,
                                      currencyCode: source.currencyCode, rateToHome: source.rateToHome, note: source.note)
                context.insert(copy)
                copy.category = source.category
                copy.paidWith = source.paidWith
                copy.repeatRule = source.repeatRule
                source.repeatRule = .never
                source = copy
            }
        }
    }

    private static func nextDate(after date: Date, rule: RepeatRule) -> Date? {
        switch rule {
        case .never: nil
        case .weekly: date.adding(days: 7)
        case .monthly: date.adding(months: 1)
        case .yearly: date.adding(months: 12)
        }
    }
}
