import SwiftUI
import SwiftData

struct TripForm: View {
    let trip: Trip?
    /// A place picked in Explore, to start a new trip there.
    var presetPlace: FoundPlace?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var search = PlaceSearch()
    @State private var destination = ""
    @State private var countryCode = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var otherCities: [String] = []
    @State private var newCity = ""
    @State private var name = ""
    @State private var nameEdited = false
    @State private var startDate = Date.now.adding(days: 14)
    @State private var endDate = Date.now.adding(days: 18)
    @State private var currency = "GBP"
    @State private var budgetText = ""
    @State private var status: TripStatus = .booked
    @State private var colorHex = "1D4ED8"
    @State private var showCountryPicker = false
    @State private var confirmDelete = false
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Where to?") {
                    if destination.isEmpty {
                        TextField("City or country", text: $search.query)
                            .textInputAutocapitalization(.words)
                        ForEach(search.results) { place in
                            Button { choose(place) } label: {
                                VStack(alignment: .leading) {
                                    Text(place.name).foregroundStyle(.primary)
                                    Text(place.address).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if search.offline || (!search.query.isEmpty && search.results.isEmpty && !search.isSearching) {
                            Button("Use \"\(search.query)\" and pick the country") {
                                destination = search.query
                                showCountryPicker = true
                            }
                        }
                    } else {
                        HStack {
                            Text(Country.flag(countryCode))
                            Text(destination).fontWeight(.semibold)
                            Spacer()
                            Button("Change") { destination = ""; search.query = "" }.font(.subheadline)
                        }
                    }
                    ForEach(otherCities, id: \.self) { city in
                        Label(city, systemImage: "mappin")
                    }
                    .onDelete { otherCities.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add another city", text: $newCity)
                        Button("Add") {
                            let trimmed = newCity.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty { otherCities.append(trimmed) }
                            newCity = ""
                        }
                        .disabled(newCity.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    TextField("Trip name", text: Binding(get: { name }, set: { name = $0; nameEdited = true }))
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                    NavigationLink {
                        CurrencyPicker(selection: $currency, suggested: [CurrencyInfo.code(forCountry: countryCode)].compactMap { $0 })
                    } label: {
                        ValueRow(label: "Trip currency", value: "\(CurrencyInfo.name(currency))\(countryCode.isEmpty ? "" : ", from \(Country.name(countryCode))")")
                    }
                    HStack {
                        Text("Budget")
                        Spacer()
                        Text(CurrencyInfo.symbol(home)).foregroundStyle(.secondary)
                        TextField("0", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Picker("Status", selection: $status) {
                        ForEach(TripStatus.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Colour") {
                    HStack {
                        ForEach(Color.palette, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: colorHex == hex ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let trip {
                    Section {
                        Button("Plan with friends") { router.present(.tripShare(trip)) }
                        Button("Delete trip", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(trip == nil ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(trip == nil ? "Create" : "Save", action: save)
                        .disabled(destination.isEmpty && name.isEmpty)
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
            .onChange(of: startDate) { _, start in
                if endDate < start { endDate = start }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPicker(selection: $countryCode) { code in
                    if let code = CurrencyInfo.code(forCountry: code) { currency = code }
                }
            }
            .confirmationDialog("Delete this trip and its plan?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete trip", role: .destructive) {
                    if let trip {
                        router.paths[.travel] = []
                        context.delete(trip)
                    }
                    dismiss()
                }
            } message: {
                Text("Spending stays in Money; documents stay in Documents.")
            }
        }
    }

    private func choose(_ place: FoundPlace) {
        destination = place.name
        countryCode = place.countryCode
        latitude = place.latitude
        longitude = place.longitude
        if let code = CurrencyInfo.code(forCountry: place.countryCode) { currency = code }
        if !nameEdited { name = place.name }
        search.query = ""
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        search.citiesOnly = true
        currency = home
        guard let trip else {
            if let presetPlace { choose(presetPlace) }
            return
        }
        destination = trip.destination
        countryCode = trip.countryCode
        latitude = trip.latitude
        longitude = trip.longitude
        otherCities = trip.otherCities
        name = trip.name
        nameEdited = true
        startDate = trip.startDate
        endDate = trip.endDate
        currency = trip.currencyCode
        budgetText = MoneyFormat.editString(trip.budgetMinor, home)
        status = trip.status
        colorHex = trip.colorHex
    }

    private func save() {
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty ? destination : name
        let target: Trip
        if let trip {
            target = trip
        } else {
            target = Trip(name: finalName, destination: destination, countryCode: countryCode, startDate: startDate, endDate: endDate, currencyCode: currency)
            context.insert(target)
        }
        target.name = finalName
        target.destination = destination
        target.countryCode = countryCode
        target.latitude = latitude
        target.longitude = longitude
        target.otherCitiesText = otherCities.joined(separator: "\n")
        target.startDate = startDate.startOfDay
        target.endDate = max(endDate, startDate).startOfDay
        target.currencyCode = currency
        target.budgetMinor = MoneyFormat.parse(budgetText, home) ?? 0
        target.status = status
        target.colorHex = colorHex
        dismiss()
        if trip == nil {
            router.show(.trip(target))
        }
    }
}

struct CountryPicker: View {
    @Binding var selection: String
    var onPick: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(Country.all.filter { query.isEmpty || Country.name($0).localizedCaseInsensitiveContains(query) }, id: \.self) { code in
                Button {
                    selection = code
                    onPick?(code)
                    dismiss()
                } label: {
                    HStack {
                        Text(Country.flag(code))
                        Text(Country.name(code)).foregroundStyle(.primary)
                        Spacer()
                        if code == selection { Image(systemName: "checkmark") }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
