import SwiftUI
import SwiftData

struct MoneyView: View {
    enum Mode: String, CaseIterable { case budget = "Budget", bills = "Bills and subscriptions" }

    @Environment(AppRouter.self) private var router
    @Environment(ExchangeRates.self) private var rates
    @Query(sort: \MoneyEntry.date, order: .reverse) private var entries: [MoneyEntry]
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query(filter: #Predicate<Bill> { !$0.isPaused }) private var bills: [Bill]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var mode: Mode = .budget
    @State private var month = Date.now.startOfMonth

    private var summary: MoneySummary {
        MoneySummary(entries: entries, categories: categories, bills: bills, month: month)
    }

    private var spendingCategories: [MoneyCategory] {
        categories.filter { !$0.isIncome && !$0.isArchived }
            .sorted { $0.total(in: month) > $1.total(in: month) }
    }

    private var monthEntries: [MoneyEntry] {
        entries.filter { $0.date.monthKey == month.monthKey }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Show", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                if mode == .budget {
                    budget
                } else {
                    BillsList()
                }
                Spacer(minLength: 70)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Money")
        .toolbar {
            if mode == .budget {
                ToolbarItem(placement: .topBarTrailing) { monthSwitcher }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(title: mode == .budget ? "Add" : "Add bill", color: Area.money.color) {
                router.present(mode == .budget ? .moneyEntry(nil) : .bill(nil))
            }
            .padding(.trailing, Theme.gutter)
            .padding(.bottom, 12)
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 2) {
            Button { month = month.adding(months: -1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Text(month.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 56)
            Button { month = month.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next month")
                .disabled(month.monthKey >= Date.now.monthKey)
        }
    }

    // MARK: Budget

    @ViewBuilder
    private var budget: some View {
        let s = summary
        Button { router.push(.monthlyPlan) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(s.planned > 0 ? "LEFT TO SPEND" : "SPENT THIS MONTH")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Area.money.color)
                Text(MoneyFormat.string(s.planned > 0 ? s.leftToSpend : s.spent, home, whole: true))
                    .font(.display(40))
                    .foregroundStyle(s.leftToSpend < 0 && s.planned > 0 ? .orange : .primary)
                if s.planned > 0 {
                    ProgressBar(value: s.usedFraction, color: Area.money.color)
                    HStack {
                        Text("\(MoneyFormat.string(s.spent, home, whole: true)) of \(MoneyFormat.string(s.planned, home, whole: true)) plan spent")
                        Spacer()
                        let days = MoneySummary.daysLeft(in: month)
                        if days > 0 && s.leftToSpend > 0 {
                            Text("\(MoneyFormat.string(s.leftToSpend / days, home, whole: true)) a day")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Set a monthly plan to see what's left ›")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Area.money.color)
                }
            }
            .card()
        }
        .buttonStyle(.plain)

        if s.income > 0 || s.plannedIncome > 0 {
            HStack {
                Label("Income", systemImage: "arrow.down.circle")
                Spacer()
                Text(MoneyFormat.string(s.income, home, whole: true)).fontWeight(.semibold)
                if s.plannedIncome > 0 {
                    Text("of \(MoneyFormat.string(s.plannedIncome, home, whole: true))").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .card()
        }

        VStack(spacing: 0) {
            HStack {
                SectionLabel(text: "Categories")
                Button("All \(spendingCategories.count) categories") { router.push(.monthlyPlan) }
                    .font(.footnote.weight(.semibold))
                    .tint(Area.money.color)
            }
            .padding(.bottom, 4)
            ForEach(spendingCategories.prefix(5)) { category in
                NavigationLink(value: Route.moneyCategory(category)) {
                    CategoryRow(category: category, month: month)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .card()

        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Recent")
                .padding(.bottom, 4)
            if monthEntries.isEmpty {
                Text("Nothing logged this month yet. Tap Add to type your first spend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            ForEach(monthEntries.prefix(8)) { entry in
                NavigationLink(value: Route.moneyEntry(entry)) {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                if entry.id != monthEntries.prefix(8).last?.id { Divider() }
            }
        }
        .card()

        if let note = rates.lastError {
            Text(note).font(.caption).foregroundStyle(.secondary)
        } else if let updated = rates.updatedAt {
            Text("Exchange rates updated \(DateText.relativeDay(updated).lowercased()).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CategoryRow: View {
    let category: MoneyCategory
    let month: Date
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    var body: some View {
        let spent = category.total(in: month)
        let plan = category.plan(for: month)
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                IconChip(symbol: category.icon, color: Color(hex: category.colorHex), size: 34)
                Text(category.name).font(.body)
                Spacer()
                Text(MoneyFormat.string(spent, home, whole: true)).fontWeight(.semibold)
                if plan > 0 {
                    Text("/ \(MoneyFormat.string(plan, home, whole: true))").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            if plan > 0 {
                ProgressBar(value: Double(spent) / Double(plan), color: Color(hex: category.colorHex), height: 5)
                    .padding(.leading, 46)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct EntryRow: View {
    let entry: MoneyEntry

    var body: some View {
        HStack(spacing: 12) {
            IconChip(symbol: entry.category?.icon ?? (entry.isIncome ? "arrow.down" : "tag"),
                     color: Color(hex: entry.category?.colorHex ?? "64748B"), size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(MoneyFormat.string(entry.amountMinor, entry.currencyCode, signed: entry.isIncome))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.isIncome ? Area.money.color : .primary)
                if entry.isForeign {
                    Text(MoneyFormat.string(entry.homeAmountMinor, entry.homeCurrencyCode))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts = [DateText.relativeDay(entry.date)]
        if let category = entry.category, !entry.note.isEmpty { parts.append(category.name) }
        if let trip = entry.trip { parts.append(trip.name) }
        return parts.joined(separator: " · ")
    }
}
