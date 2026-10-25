import SwiftUI
import SwiftData
import PhotosUI

/// Add or edit spending or income. Opened from Money, the + button, a trip's
/// budget and a category, always as this same form. Inside a trip it starts
/// in the trip's currency with the trip already set.
struct MoneyEntryForm: View {
    let entry: MoneyEntry?
    var presetCategory: MoneyCategory?
    var presetTrip: Trip?
    var startAsIncome = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ExchangeRates.self) private var rates
    @Query(sort: \MoneyCategory.sortOrder) private var categories: [MoneyCategory]
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var isIncome = false
    @State private var amountText = ""
    @State private var currency = "GBP"
    /// A rate typed by hand, kept only for the currency it was typed for.
    @State private var manualRate: (code: String, value: Double)?
    @State private var rateText = ""
    @State private var isEditingRate = false
    @State private var category: MoneyCategory?
    @State private var date = Date.now
    @State private var note = ""
    @State private var trip: Trip?
    @State private var paidWith = ""
    @State private var repeatRule: RepeatRule = .never
    @State private var receipt: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showNewCategory = false
    @State private var showReceipt = false
    @State private var confirmDelete = false
    @State private var didLoad = false
    @FocusState private var amountFocused: Bool

    private var amountMinor: Int { MoneyFormat.parse(amountText, currency) ?? 0 }

    private var rate: Double {
        if let manualRate, manualRate.code == currency { return manualRate.value }
        return rates.rate(from: currency, to: home) ?? 1
    }

    private var homeAmount: Int {
        MoneyFormat.convert(amountMinor, from: currency, to: home, rate: rate)
    }

    private var visibleCategories: [MoneyCategory] {
        categories.filter { $0.isIncome == isIncome && !$0.isArchived }
    }

    private var tripChoices: [Trip] {
        trips.filter { !$0.isPast || $0 == trip }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isIncome) {
                        Text("Spending").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            AmountField(text: $amountText, currencyCode: currency)
                                .focused($amountFocused)
                            NavigationLink {
                                CurrencyPicker(selection: $currency, suggested: [trip?.currencyCode].compactMap { $0 })
                            } label: {
                                Text(currency)
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Area.money.tint, in: Capsule())
                                    .foregroundStyle(Area.money.color)
                            }
                            .fixedSize()
                        }
                        if currency != home {
                            rateLine
                        }
                    }
                }

                Section("Category") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(visibleCategories) { item in
                            categoryTile(item)
                        }
                        Button { showNewCategory = true } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "plus").font(.title3)
                                Text("New").font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .foregroundStyle(.secondary)
                            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (what was it?)", text: $note)
                    Picker("Trip", selection: Binding(get: { trip }, set: { chooseTrip($0) })) {
                        Text("None").tag(Trip?.none)
                        ForEach(tripChoices) { item in
                            Text(item.name).tag(Trip?.some(item))
                        }
                    }
                    TextField("Paid with (card, cash…)", text: $paidWith)
                    Picker("Repeat", selection: $repeatRule) {
                        ForEach(RepeatRule.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Receipt") {
                    if let receipt, let image = UIImage(data: receipt) {
                        HStack {
                            Button { showReceipt = true } label: {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 56, height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button("Remove", role: .destructive) { self.receipt = nil }
                        }
                    } else {
                        Button { showCamera = true } label: { Label("Take a photo", systemImage: "camera") }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Choose from photos", systemImage: "photo")
                        }
                    }
                }

                if entry != nil {
                    Section {
                        Button("Delete entry", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(entry == nil ? (isIncome ? "Add income" : "Add spending") : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(amountMinor <= 0).fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
            .onChange(of: isIncome) { _, income in
                if category?.isIncome != income { category = nil }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        receipt = ImageTools.compressedJPEG(data)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in receipt = ImageTools.compressedJPEG(image) }.ignoresSafeArea()
            }
            .sheet(isPresented: $showNewCategory) {
                CategoryForm(category: nil, startAsIncome: isIncome) { created in category = created }
            }
            .fullScreenCover(isPresented: $showReceipt) {
                if let receipt, let image = UIImage(data: receipt) { ZoomableImage(image: image) }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry { context.delete(entry) }
                    dismiss()
                }
            }
        }
    }

    private var rateLine: some View {
        HStack {
            if isEditingRate {
                Text("1 \(currency) =")
                TextField("rate", text: $rateText)
                    .keyboardType(.decimalPad)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(applyRate)
                Text(home)
                Spacer()
                Button("Done", action: applyRate).font(.footnote.weight(.semibold))
            } else {
                Text("≈ \(MoneyFormat.string(homeAmount, home)) · 1 \(currency) = \(rate.formatted(.number.precision(.significantDigits(4)))) \(home)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Edit rate") {
                    rateText = rate.formatted(.number.precision(.significantDigits(5)).grouping(.never))
                    isEditingRate = true
                }
                .font(.footnote.weight(.semibold))
                .tint(Area.money.color)
            }
        }
        .font(.footnote)
    }

    private func applyRate() {
        let cleaned = rateText.replacingOccurrences(of: ",", with: ".")
        if let value = Double(cleaned), value > 0 { manualRate = (code: currency, value: value) }
        isEditingRate = false
    }

    /// Picking a trip switches to its currency, unless an amount in another currency is already typed.
    private func chooseTrip(_ newTrip: Trip?) {
        trip = newTrip
        if let newTrip, amountText.isEmpty || currency == home {
            currency = newTrip.currencyCode
        }
    }

    private func categoryTile(_ item: MoneyCategory) -> some View {
        let selected = item == category
        let color = Color(hex: item.colorHex)
        return Button { category = item } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon).font(.title3)
                Text(item.name).font(.caption).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .foregroundStyle(selected ? .white : color)
            .background(selected ? color : color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let entry {
            isIncome = entry.isIncome
            amountText = MoneyFormat.editString(entry.amountMinor, entry.currencyCode)
            currency = entry.currencyCode
            manualRate = (code: entry.currencyCode, value: entry.rateToHome)
            category = entry.category
            date = entry.date
            note = entry.note
            trip = entry.trip
            paidWith = entry.paidWith
            repeatRule = entry.repeatRule
            receipt = entry.receipt
        } else {
            isIncome = startAsIncome || (presetCategory?.isIncome ?? false)
            currency = presetTrip?.currencyCode ?? home
            category = presetCategory ?? (presetTrip != nil ? categories.first { $0.name == "Travel" } : nil)
            trip = presetTrip ?? trips.first(where: \.isUnderway)
            if let trip, presetTrip == nil { currency = trip.currencyCode }
            amountFocused = true
        }
    }

    private func save() {
        let target: MoneyEntry
        if let entry {
            target = entry
        } else {
            target = MoneyEntry(amountMinor: amountMinor, currencyCode: currency, rateToHome: rate)
            context.insert(target)
        }
        target.isIncome = isIncome
        target.amountMinor = amountMinor
        target.currencyCode = currency
        target.rateToHome = rate
        target.updateHomeAmount()
        target.category = category
        target.date = date
        target.note = note.trimmingCharacters(in: .whitespaces)
        target.trip = trip
        target.paidWith = paidWith
        target.repeatRule = repeatRule
        target.receipt = receipt
        dismiss()
    }
}
