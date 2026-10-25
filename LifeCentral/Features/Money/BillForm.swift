import SwiftUI
import SwiftData

struct BillForm: View {
    let bill: Bill?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query private var allBills: [Bill]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var name = ""
    @State private var amountText = ""
    @State private var currency = "GBP"
    @State private var frequency: BillFrequency = .monthly
    @State private var group = "Home"
    @State private var newGroup = ""
    @State private var showNewGroup = false
    @State private var nextDue = Date.now
    @State private var remindDays = 3
    @State private var paidFrom = ""
    @State private var countInPlan = true
    @State private var category: MoneyCategory?
    @State private var notes = ""
    @State private var showAddDocument = false
    @State private var confirmDelete = false
    @State private var didLoad = false

    private var amountMinor: Int { MoneyFormat.parse(amountText, currency) ?? 0 }

    private var groupChoices: [String] {
        var list = BillGroup.defaults
        for name in allBills.map(\.group) where !list.contains(name) { list.append(name) }
        if !list.contains(group) { list.append(group) }
        return list
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Car insurance", text: $name)
                    HStack {
                        AmountField(text: $amountText, currencyCode: currency, font: .display(30))
                        NavigationLink {
                            CurrencyPicker(selection: $currency)
                        } label: {
                            Text(currency).font(.subheadline.weight(.bold)).foregroundStyle(Area.money.color)
                        }
                        .fixedSize()
                    }
                    Picker("How often", selection: $frequency) {
                        ForEach(BillFrequency.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Group") {
                    FlowLayout {
                        ForEach(groupChoices, id: \.self) { item in
                            ChoiceChip(title: item, isOn: group == item, color: Area.money.color) { group = item }
                        }
                        ChoiceChip(title: "+ New group", isOn: false) { showNewGroup = true }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    DatePicker(frequency == .once ? "Due" : "Next due", selection: $nextDue, displayedComponents: .date)
                    Stepper("Remind me \(remindDays == 0 ? "on the day" : "\(remindDays) day\(remindDays == 1 ? "" : "s") before")",
                            value: $remindDays, in: 0...30)
                    TextField("Paid from (account or card)", text: $paidFrom)
                    Toggle("Count in monthly plan", isOn: $countInPlan)
                    Picker("Category when paid", selection: $category) {
                        Text("None").tag(MoneyCategory?.none)
                        ForEach(categories.filter { !$0.isIncome && !$0.isArchived }) { Text($0.name).tag(MoneyCategory?.some($0)) }
                    }
                    TextField("Notes (policy number, account…)", text: $notes, axis: .vertical)
                }

                Section("Documents") {
                    if let bill {
                        ForEach(bill.documents ?? []) { doc in
                            Label(doc.title, systemImage: "doc.text")
                        }
                        Button { showAddDocument = true } label: { Label("Attach policy or contract", systemImage: "paperclip") }
                    } else {
                        Text("Save the bill first, then attach its policy or contract.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let bill {
                    Section {
                        Button("Mark paid now") {
                            bill.markPaid(in: context)
                            dismiss()
                        }
                        Button(bill.isPaused ? "Resume" : "Pause") { bill.isPaused.toggle() }
                        Button("Delete bill", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("Marking paid adds it to Money and moves the due date on.")
                    }
                }
            }
            .navigationTitle(bill == nil ? "Add bill" : "Edit bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amountMinor <= 0)
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
            .alert("New group", isPresented: $showNewGroup) {
                TextField("Name", text: $newGroup)
                Button("Add") {
                    let trimmed = newGroup.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { group = trimmed }
                    newGroup = ""
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showAddDocument) {
                if let bill { DocumentAddSheet(presetFolder: group == "Car" ? "Car" : "Home", bill: bill) }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let bill { context.delete(bill) }
                    dismiss()
                }
            } message: {
                Text("Past payments stay in Money.")
            }
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let bill {
            name = bill.name
            amountText = MoneyFormat.editString(bill.amountMinor, bill.currencyCode)
            currency = bill.currencyCode
            frequency = bill.frequency
            group = bill.group
            nextDue = bill.nextDue
            remindDays = bill.remindDaysBefore
            paidFrom = bill.paidFrom
            countInPlan = bill.countInPlan
            category = bill.category
            notes = bill.notes
        } else {
            currency = home
            remindDays = UserDefaults.standard.object(forKey: SettingsKey.billReminderDays) as? Int ?? 3
            category = categories.first { $0.name == "Home" }
        }
    }

    private func save() {
        let target: Bill
        if let bill {
            target = bill
        } else {
            target = Bill(name: name, amountMinor: amountMinor, currencyCode: currency, frequency: frequency, group: group, nextDue: nextDue)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.amountMinor = amountMinor
        target.currencyCode = currency
        target.frequency = frequency
        target.group = group
        target.nextDue = nextDue.startOfDay
        target.remindDaysBefore = remindDays
        target.paidFrom = paidFrom
        target.countInPlan = countInPlan
        target.category = category
        target.notes = notes
        dismiss()
    }
}
