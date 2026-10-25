import SwiftUI
import SwiftData

struct MoneyEntryDetail: View {
    let entry: MoneyEntry
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showReceipt = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.isIncome ? "INCOME" : "SPENDING")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Area.money.color)
                    Text(MoneyFormat.string(entry.amountMinor, entry.currencyCode, signed: entry.isIncome))
                        .font(.display(38))
                    if entry.isForeign {
                        Text("\(MoneyFormat.string(entry.homeAmountMinor, entry.homeCurrencyCode)) at 1 \(entry.currencyCode) = \(entry.rateToHome.formatted(.number.precision(.significantDigits(4)))) \(entry.homeCurrencyCode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.title).font(.headline).padding(.top, 4)
                }
                .padding(.vertical, 6)
            }

            Section {
                if let category = entry.category {
                    NavigationLink(value: Route.moneyCategory(category)) {
                        ValueRow(label: "Category", value: category.name)
                    }
                } else {
                    ValueRow(label: "Category", value: "None")
                }
                ValueRow(label: "Date", value: entry.date.formatted(date: .complete, time: .omitted))
                if !entry.paidWith.isEmpty { ValueRow(label: "Paid with", value: entry.paidWith) }
                if entry.repeatRule != .never { ValueRow(label: "Repeats", value: entry.repeatRule.title) }
                if let trip = entry.trip {
                    NavigationLink(value: Route.trip(trip)) { ValueRow(label: "Trip", value: trip.name) }
                }
                if entry.bill != nil {
                    NavigationLink(value: Route.bills) { ValueRow(label: "Bill payment", value: entry.bill?.name ?? "") }
                }
            }

            if let data = entry.receipt, let image = UIImage(data: data) {
                Section("Receipt") {
                    Button { showReceipt = true } label: {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button { router.present(.moneyEntry(entry)) } label: { Label("Edit", systemImage: "pencil") }
                Button(action: duplicate) { Label("Duplicate for today", systemImage: "plus.square.on.square") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
            }
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showReceipt) {
            if let data = entry.receipt, let image = UIImage(data: data) { ZoomableImage(image: image) }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(entry)
                dismiss()
            }
        }
    }

    private func duplicate() {
        let copy = MoneyEntry(date: .now, isIncome: entry.isIncome, amountMinor: entry.amountMinor,
                              currencyCode: entry.currencyCode, rateToHome: entry.rateToHome, note: entry.note)
        context.insert(copy)
        copy.category = entry.category
        copy.trip = entry.trip
        copy.paidWith = entry.paidWith
        router.present(.moneyEntry(copy))
    }
}
