import SwiftUI
import SwiftData

/// Bills and subscriptions screen when opened on its own (from the plan, search or inbox).
struct BillsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            BillsList()
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 80)
        }
        .screenBackground()
        .navigationTitle("Bills and subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            FloatingAddButton(title: "Add bill", color: Area.money.color) { router.present(.bill(nil)) }
                .padding(.trailing, Theme.gutter)
                .padding(.bottom, 12)
        }
    }
}

/// Bills grouped (Home, Car, Subscriptions…) with a monthly total. Used inside
/// the Money tab and on its own screen.
struct BillsList: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \Bill.nextDue) private var bills: [Bill]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"
    @State private var expanded: Set<String> = []

    private var active: [Bill] { bills.filter { !$0.isPaused } }

    private var groups: [(name: String, bills: [Bill])] {
        let grouped = Dictionary(grouping: bills, by: \.group)
        return grouped.keys.sorted { a, b in
            let ia = BillGroup.defaults.firstIndex(of: a) ?? 99
            let ib = BillGroup.defaults.firstIndex(of: b) ?? 99
            return ia == ib ? a < b : ia < ib
        }.map { (name: $0, bills: grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let monthly = active.reduce(0) { $0 + $1.monthlyHomeMinor }
            let dueThisWeek = active.filter { $0.nextDue.daysFromToday <= 7 }
            VStack(alignment: .leading, spacing: 6) {
                Text("EVERY MONTH").font(.caption.weight(.bold)).foregroundStyle(Area.money.color)
                Text(MoneyFormat.string(monthly, home, whole: true)).font(.display(36))
                Text(dueThisWeek.isEmpty
                     ? "Nothing due in the next 7 days"
                     : "\(dueThisWeek.count) due in the next 7 days · \(MoneyFormat.string(dueThisWeek.reduce(0) { $0 + $1.amountMinor }, home, whole: true))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .card()

            if bills.isEmpty {
                EmptyState(symbol: "clock.arrow.circlepath", title: "No bills yet",
                           message: "Add rent, council tax, car insurance, phone and streaming. You'll get a reminder before each one is due.",
                           actionTitle: "Add a bill", color: Area.money.color) { router.present(.bill(nil)) }
                    .card()
            }

            ForEach(groups, id: \.name) { group in
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        IconChip(symbol: BillGroup.icon(for: group.name), color: Area.money.color, size: 30)
                        Text(group.name).font(.headline)
                        Spacer()
                        Text("\(MoneyFormat.string(group.bills.reduce(0) { $0 + $1.monthlyHomeMinor }, home, whole: true))/mo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)
                    ForEach(group.bills) { bill in
                        BillRow(bill: bill)
                        if bill.id != group.bills.last?.id { Divider() }
                    }
                }
                .card()
            }
            if !bills.isEmpty {
                Text("Tap a bill to edit it. Hold it to mark it paid or pause it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct BillRow: View {
    let bill: Bill
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    var body: some View {
        Button { router.present(.bill(bill)) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(bill.isPaused ? .secondary : .primary)
                    Text(bill.isPaused ? "Paused" : "Next \(DateText.relativeDay(bill.nextDue)) · \(DateText.countdown(bill.nextDue))")
                        .font(.caption)
                        .foregroundStyle(bill.isDueSoon ? Color.orange : .secondary)
                }
                Spacer()
                Text(MoneyFormat.string(bill.amountMinor, bill.currencyCode) + bill.frequency.short)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bill.isPaused ? .secondary : .primary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !bill.isPaused {
                Button { bill.markPaid(in: context) } label: { Label("Mark paid", systemImage: "checkmark.circle") }
            }
            Button { bill.isPaused.toggle() } label: {
                Label(bill.isPaused ? "Resume" : "Pause", systemImage: bill.isPaused ? "play" : "pause")
            }
            Button(role: .destructive) { context.delete(bill) } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
