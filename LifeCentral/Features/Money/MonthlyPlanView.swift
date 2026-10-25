import SwiftUI
import SwiftData

/// How much you plan to spend in each category this month, and what you
/// expect to earn. Bills are added on top automatically.
struct MonthlyPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query private var entries: [MoneyEntry]
    @Query(filter: #Predicate<Bill> { !$0.isPaused }) private var bills: [Bill]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var month = Date.now.startOfMonth
    @State private var everyMonth = true
    @State private var editing: MoneyCategory?
    @State private var editText = ""
    @State private var showNewCategory = false

    private var summary: MoneySummary {
        MoneySummary(entries: entries, categories: categories, bills: bills, month: month)
    }

    private var spending: [MoneyCategory] { categories.filter { !$0.isIncome && !$0.isArchived } }
    private var income: [MoneyCategory] { categories.filter { $0.isIncome && !$0.isArchived } }

    var body: some View {
        let s = summary
        List {
            Section {
                HStack {
                    Button { month = month.adding(months: -1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Previous month")
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button { month = month.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Next month")
                }
                HStack(spacing: 0) {
                    totalBox("Expected in", s.plannedIncome)
                    totalBox("Planned out", s.planned)
                    totalBox("Spare", s.plannedIncome - s.planned, highlight: true)
                }
                Picker("Changes apply to", selection: $everyMonth) {
                    Text("Every month").tag(true)
                    Text("Only \(month.formatted(.dateTime.month(.wide)))").tag(false)
                }
                .pickerStyle(.segmented)
                Button("Copy plan from last month", action: copyLastMonth)
                    .font(.subheadline)
            }

            Section("Income") {
                ForEach(income) { planRow($0) }
            }

            Section {
                NavigationLink(value: Route.bills) {
                    HStack {
                        IconChip(symbol: "clock.arrow.circlepath", color: Area.money.color, size: 34)
                        Text("Bills and subscriptions")
                        Spacer()
                        Text(MoneyFormat.string(s.billsMonthly, home, whole: true)).foregroundStyle(.secondary)
                    }
                }
                ForEach(spending) { planRow($0) }
                Button { showNewCategory = true } label: { Label("New category", systemImage: "plus") }
            } header: {
                Text("Spending")
            } footer: {
                Text("Tap an amount to change it. Bills count automatically, averaged per month.")
            }
        }
        .navigationTitle("Monthly plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewCategory) { CategoryForm(category: nil) }
        .alert("Plan for \(editing?.name ?? "")", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Amount", text: $editText).keyboardType(.decimalPad)
            Button("Save") {
                if let editing {
                    editing.setPlan(MoneyFormat.parse(editText, home) ?? 0, for: month, everyMonth: everyMonth, in: context)
                }
                editing = nil
            }
            Button("Cancel", role: .cancel) { editing = nil }
        } message: {
            Text(everyMonth ? "Applies from this month on." : "Applies to \(month.formatted(.dateTime.month(.wide))) only.")
        }
    }

    private func totalBox(_ label: String, _ value: Int, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(MoneyFormat.string(value, home, whole: true))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(highlight ? (value < 0 ? Color.orange : Area.money.color) : .primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func planRow(_ category: MoneyCategory) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: Route.moneyCategory(category)) {
                HStack(spacing: 12) {
                    IconChip(symbol: category.icon, color: Color(hex: category.colorHex), size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(category.name)
                        Text("\(category.isIncome ? "Received" : "Spent") \(MoneyFormat.string(category.total(in: month), home, whole: true))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                editText = MoneyFormat.editString(category.plan(for: month), home)
                editing = category
            } label: {
                Text(category.plan(for: month) > 0 ? MoneyFormat.string(category.plan(for: month), home, whole: true) : "Set")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Area.money.tint, in: Capsule())
                    .foregroundStyle(Area.money.color)
            }
            .buttonStyle(.borderless)
        }
    }

    private func copyLastMonth() {
        let previous = month.adding(months: -1)
        for category in categories where !category.isArchived {
            category.setPlan(category.plan(for: previous), for: month, everyMonth: false, in: context)
        }
    }
}
