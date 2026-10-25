import SwiftUI
import SwiftData
import Charts

struct CategoryDetailView: View {
    let category: MoneyCategory
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"
    @State private var selectedMonth = Date.now.startOfMonth
    @State private var showEdit = false
    @State private var showAll = false

    private var color: Color { Color(hex: category.colorHex) }

    private var months: [Date] {
        (0..<6).reversed().map { Date.now.startOfMonth.adding(months: -$0) }
    }

    private var monthEntries: [MoneyEntry] {
        (category.entries ?? []).filter { $0.date.monthKey == selectedMonth.monthKey }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        IconChip(symbol: category.icon, color: color, size: 44)
                        VStack(alignment: .leading) {
                            Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                                .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            let spent = category.total(in: selectedMonth)
                            let plan = category.plan(for: selectedMonth)
                            Text(plan > 0
                                 ? "\(MoneyFormat.string(spent, home, whole: true)) of \(MoneyFormat.string(plan, home, whole: true))"
                                 : MoneyFormat.string(spent, home, whole: true))
                                .font(.display(26))
                        }
                    }
                    Chart(months, id: \.self) { month in
                        BarMark(
                            x: .value("Month", month, unit: .month),
                            y: .value("Total", MoneyFormat.double(category.total(in: month), home)),
                            width: .ratio(0.55)
                        )
                        .foregroundStyle(month.monthKey == selectedMonth.monthKey ? color : color.opacity(0.35))
                        .cornerRadius(4)
                        if category.plan(for: month) > 0 && month.monthKey == selectedMonth.monthKey {
                            RuleMark(y: .value("Plan", MoneyFormat.double(category.plan(for: month), home)))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                            AxisValueLabel()
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    let originX = proxy.plotFrame.map { geo[$0].origin.x } ?? 0
                                    if let date: Date = proxy.value(atX: location.x - originX) {
                                        selectedMonth = date.startOfMonth
                                    }
                                }
                        }
                    }
                    .frame(height: 150)
                    .accessibilityLabel("Monthly totals for \(category.name)")
                    Text("Tap a bar to see that month. The dashed line is your plan.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Entries") {
                if monthEntries.isEmpty {
                    Text("Nothing in this category for the month.").foregroundStyle(.secondary)
                }
                ForEach(showAll ? monthEntries : Array(monthEntries.prefix(8))) { entry in
                    NavigationLink(value: Route.moneyEntry(entry)) { EntryRow(entry: entry) }
                }
                if monthEntries.count > 8 && !showAll {
                    Button("See all \(monthEntries.count)") { showAll = true }
                }
            }

            Section {
                Button { router.present(.moneyEntry(nil, category: category)) } label: {
                    Label("Add entry", systemImage: "plus")
                }
                NavigationLink(value: Route.monthlyPlan) { Label("Change plan", systemImage: "slider.horizontal.3") }
                Button { showEdit = true } label: { Label("Edit category", systemImage: "pencil") }
            }
        }
        .navigationTitle(category.name)
        .sheet(isPresented: $showEdit) { CategoryForm(category: category) }
    }
}
