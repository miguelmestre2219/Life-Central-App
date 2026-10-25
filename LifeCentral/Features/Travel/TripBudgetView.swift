import SwiftUI
import SwiftData

struct TripBudgetView: View {
    let trip: Trip

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRates.self) private var rates
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"
    @State private var showBudgetEditor = false
    @State private var budgetText = ""

    private var spending: [MoneyEntry] {
        (trip.entries ?? []).filter { !$0.isIncome }.sorted { $0.date > $1.date }
    }
    private var unpaid: [TripItem] {
        (trip.items ?? []).filter { $0.costMinor > 0 && !$0.isPaid }.sorted { $0.day < $1.day }
    }
    private var spent: Int { trip.spentHomeMinor }
    private var planned: Int { trip.plannedHomeMinor }

    private var byCategory: [(name: String, color: Color, total: Int)] {
        let groups = Dictionary(grouping: spending) { $0.category?.name ?? "Other" }
        return groups.map { name, entries in
            let hex = entries.first?.category?.colorHex ?? "64748B"
            return (name: name, color: Color(hex: hex), total: entries.reduce(0) { $0 + $1.homeAmountMinor })
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                if !byCategory.isEmpty { categories }
                if !unpaid.isEmpty { plannedCosts }
                entries
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 90)
        }
        .screenBackground()
        .overlay(alignment: .bottom) {
            FloatingAddButton(title: "Add spending", color: Area.money.color) {
                router.present(.moneyEntry(nil, trip: trip))
            }
            .padding(.bottom, 12)
        }
        .navigationTitle("Trip budget")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Trip budget", isPresented: $showBudgetEditor) {
            TextField("Amount in \(home)", text: $budgetText).keyboardType(.decimalPad)
            Button("Save") { trip.budgetMinor = MoneyFormat.parse(budgetText, home) ?? 0 }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("In \(CurrencyInfo.name(home)). Spending in other currencies is converted.")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(MoneyFormat.string(spent, home)).font(.display(34))
                }
                Spacer()
                Button(trip.budgetMinor > 0 ? "of \(MoneyFormat.string(trip.budgetMinor, home, whole: true))" : "Set budget") {
                    budgetText = trip.budgetMinor > 0 ? MoneyFormat.editString(trip.budgetMinor, home) : ""
                    showBudgetEditor = true
                }
                .font(.subheadline.weight(.semibold))
                .tint(Area.money.color)
            }
            if trip.budgetMinor > 0 {
                let budget = Double(trip.budgetMinor)
                ProgressBar(value: Double(spent) / budget, color: Area.money.color,
                            secondValue: Double(planned) / budget, secondColor: Area.money.color.opacity(0.35), height: 10)
                let left = trip.budgetMinor - spent - planned
                Text(left >= 0
                     ? "\(MoneyFormat.string(left, home, whole: true)) left after \(MoneyFormat.string(planned, home, whole: true)) still to pay"
                     : "\(MoneyFormat.string(-left, home, whole: true)) over, counting what's still to pay")
                    .font(.footnote)
                    .foregroundStyle(left >= 0 ? Color.secondary : Color.orange)
            } else if planned > 0 {
                Text("\(MoneyFormat.string(planned, home, whole: true)) planned and not paid yet")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if trip.currencyCode != home {
                Divider()
                HStack {
                    Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                    if let rate = rates.rate(from: trip.currencyCode, to: home) {
                        Text(rateText(rate))
                    } else {
                        Text("Exchange rate for \(trip.currencyCode) loads when you're online")
                    }
                    Spacer()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .card(padding: 16)
    }

    /// "1 EUR = £0.86", or "100 JPY = £0.52" when one unit is worth very little.
    private func rateText(_ rate: Double) -> String {
        var units = 1.0
        while rate * units < 0.1 && units < 1_000_000 { units *= 10 }
        let value = (rate * units).formatted(.currency(code: home).precision(.fractionLength(2)))
        return "\(Int(units).formatted()) \(trip.currencyCode) = \(value)"
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Where it went")
            ForEach(byCategory, id: \.name) { group in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.name).font(.subheadline)
                        Spacer()
                        Text(MoneyFormat.string(group.total, home, whole: true)).font(.subheadline.weight(.semibold))
                    }
                    ProgressBar(value: spent > 0 ? Double(group.total) / Double(spent) : 0, color: group.color, height: 6)
                }
            }
        }
        .card(padding: 16)
    }

    private var plannedCosts: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "Planned, not paid yet")
            ForEach(unpaid) { item in
                HStack(spacing: 12) {
                    IconChip(symbol: item.kind.icon, color: Color(hex: trip.colorHex), size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("Day \(trip.dayNumber(item.day)) · \(MoneyFormat.string(item.costMinor, item.costCurrency))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Paid") { item.recordPayment(in: context) }
                        .buttonStyle(.bordered)
                        .tint(Area.money.color)
                        .font(.footnote.weight(.semibold))
                        .accessibilityLabel("Mark \(item.title) paid")
                }
                .padding(.vertical, 6)
            }
            Text("Tapping Paid adds it to Money under Travel, linked to this trip.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .card(padding: 16)
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "Spending on this trip").padding(.bottom, 6)
            if spending.isEmpty {
                Text("Nothing yet. Anything you add with this trip picked shows up here.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            ForEach(spending) { entry in
                NavigationLink(value: Route.moneyEntry(entry)) { EntryRow(entry: entry) }
                    .buttonStyle(.plain)
            }
        }
        .card(padding: 16)
    }
}
