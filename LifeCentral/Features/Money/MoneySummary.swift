import Foundation

/// Totals for one month, all in the home currency. Shared by Money and Today
/// so both always show the same numbers.
struct MoneySummary {
    var income = 0
    var spent = 0
    /// Planned spending: every category's plan plus bills that count in the plan.
    var planned = 0
    var plannedIncome = 0
    var billsMonthly = 0

    var leftToSpend: Int { planned - spent }

    /// Fraction of the plan used, for progress bars.
    var usedFraction: Double {
        planned > 0 ? Double(spent) / Double(planned) : 0
    }

    init(entries: [MoneyEntry], categories: [MoneyCategory], bills: [Bill], month: Date) {
        let key = month.monthKey
        for entry in entries where entry.date.monthKey == key {
            if entry.isIncome { income += entry.homeAmountMinor } else { spent += entry.homeAmountMinor }
        }
        for category in categories where !category.isArchived {
            if category.isIncome {
                plannedIncome += category.plan(for: month)
            } else {
                planned += category.plan(for: month)
            }
        }
        billsMonthly = bills.filter(\.countInPlan).reduce(0) { $0 + $1.monthlyHomeMinor }
        planned += billsMonthly
    }

    /// Days left in the month including today, for "£18 a day" hints.
    static func daysLeft(in month: Date) -> Int {
        guard month.monthKey == Date.now.monthKey,
              let range = Calendar.app.range(of: .day, in: .month, for: month) else { return 0 }
        let today = Calendar.app.component(.day, from: .now)
        return range.count - today + 1
    }
}
