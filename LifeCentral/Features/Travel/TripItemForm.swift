import SwiftUI
import SwiftData
import MapKit

struct TripItemForm: View {
    let item: TripItem?
    var presetTrip: Trip?
    var presetDay: Date?
    /// A place picked in Explore, to add to a trip.
    var presetPlace: FoundPlace?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router
    @Environment(ExchangeRates.self) private var rates
    @Query(sort: \Trip.startDate) private var allTrips: [Trip]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var trip: Trip?
    @State private var day = Date.now.startOfDay
    @State private var kind: TripItemKind = .activity
    @State private var title = ""
    @State private var search = PlaceSearch()
    @State private var placeName = ""
    @State private var address = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var hasTime = true
    @State private var time = Calendar.app.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    @State private var duration = 60
    @State private var costText = ""
    @State private var currency = "GBP"
    @State private var booking: BookingStatus = .none
    @State private var notes = ""
    @State private var addToMoney = false
    @State private var showAddDocument = false
    @State private var confirmDelete = false
    @State private var didLoad = false

    private var trips: [Trip] { allTrips.filter { !$0.isPast || $0 === trip } }
    private var costMinor: Int { MoneyFormat.parse(costText, currency) ?? 0 }
    private var isPaid: Bool { item?.isPaid ?? false }

    var body: some View {
        NavigationStack {
            Form {
                if presetTrip == nil && item == nil {
                    tripSection
                }

                Section {
                    FlowLayout {
                        ForEach(TripItemKind.allCases) { option in
                            ChoiceChip(title: option.title, isOn: kind == option, color: tripColor) { kind = option }
                        }
                    }
                    .padding(.vertical, 4)
                    TextField(titlePrompt, text: $title)
                }

                placeSection

                Section("When") {
                    if let trip {
                        Picker("Day", selection: $day) {
                            ForEach(Array(trip.days.enumerated()), id: \.offset) { index, date in
                                Text("Day \(index + 1) · \(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))").tag(date)
                            }
                        }
                    }
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Starts", selection: $time, displayedComponents: .hourAndMinute)
                        Stepper("Takes \(DateText.duration(minutes: duration))", value: $duration, in: 15...1440, step: 15)
                    }
                }

                costSection

                Section {
                    Picker("Booking", selection: $booking) {
                        ForEach(BookingStatus.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("Notes, booking reference…", text: $notes, axis: .vertical)
                }

                Section("Tickets") {
                    if let item {
                        ForEach(item.documents ?? []) { doc in
                            Label(doc.title, systemImage: "doc.text")
                        }
                        Button { showAddDocument = true } label: { Label("Attach ticket or confirmation", systemImage: "paperclip") }
                    } else {
                        Text("Save first, then attach a ticket or confirmation.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let item {
                    Section {
                        if let url = GoogleMapsLink.place(item), item.hasLocation || !item.placeName.isEmpty {
                            Button("Open in Google Maps") { openURL(url) }
                        }
                        Button("Delete from plan", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(item == nil ? "Add to trip" : "Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trip == nil || (title.trimmingCharacters(in: .whitespaces).isEmpty && placeName.isEmpty))
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
            .onChange(of: trip) { _, newTrip in
                guard let newTrip else { return }
                if !newTrip.days.contains(where: { $0.isSameDay(as: day) }) { day = newTrip.startDate.startOfDay }
                if item == nil && costText.isEmpty { currency = newTrip.currencyCode }
                biasSearch(to: newTrip)
            }
            .sheet(isPresented: $showAddDocument) {
                if let item { DocumentAddSheet(presetFolder: "Travel", trip: item.trip, tripItem: item) }
            }
            .confirmationDialog("Delete \(title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let item { context.delete(item) }
                    dismiss()
                }
            } message: {
                Text(isPaid ? "What you paid stays in Money." : "This removes it from the day plan.")
            }
        }
    }

    private var tripColor: Color { trip.map { Color(hex: $0.colorHex) } ?? Area.travel.color }

    private var titlePrompt: String {
        switch kind {
        case .activity: "What are you doing?"
        case .food: "Where are you eating?"
        case .transport: "e.g. Train to Kyoto"
        case .stay: "Hotel or apartment"
        case .flight: "e.g. BA 2490 to Lisbon"
        case .free: "e.g. Beach afternoon"
        }
    }

    @ViewBuilder
    private var tripSection: some View {
        Section("Trip") {
            if trips.isEmpty {
                Text("You have no upcoming trips yet.").foregroundStyle(.secondary)
                Button("Plan a trip") { router.present(.trip(nil)) }
            } else {
                Picker("Trip", selection: $trip) {
                    Text("Choose").tag(Trip?.none)
                    ForEach(trips) { Text($0.name).tag(Trip?.some($0)) }
                }
            }
        }
    }

    @ViewBuilder
    private var placeSection: some View {
        Section {
            if placeName.isEmpty {
                TextField("Search for a place", text: $search.query)
                ForEach(search.results) { place in
                    Button { choose(place) } label: {
                        VStack(alignment: .leading) {
                            Text(place.name).foregroundStyle(.primary)
                            Text(place.address).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if search.isSearching {
                    ProgressView()
                }
                if !search.query.isEmpty {
                    Button("Use \"\(search.query)\" without a map pin") {
                        placeName = search.query
                        search.query = ""
                    }
                }
            } else {
                HStack(alignment: .top) {
                    Image(systemName: latitude == nil ? "mappin.slash" : "mappin.circle.fill").foregroundStyle(tripColor)
                    VStack(alignment: .leading) {
                        Text(placeName).fontWeight(.semibold)
                        if !address.isEmpty { Text(address).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button("Change") {
                        placeName = ""
                        address = ""
                        latitude = nil
                        longitude = nil
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Place")
        } footer: {
            if search.offline {
                Text("Place search needs internet. You can type the name and add the pin later.")
            }
        }
    }

    @ViewBuilder
    private var costSection: some View {
        Section {
            HStack {
                AmountField(text: $costText, currencyCode: currency, font: .title2.weight(.semibold))
                NavigationLink {
                    CurrencyPicker(selection: $currency, suggested: [trip?.currencyCode, home].compactMap { $0 })
                } label: {
                    Text(currency).font(.subheadline.weight(.bold)).foregroundStyle(Area.money.color)
                }
                .fixedSize()
            }
            if costMinor > 0 && currency != home {
                if let rate = rates.rate(from: currency, to: home) {
                    Text("About \(MoneyFormat.string(MoneyFormat.convert(costMinor, from: currency, to: home, rate: rate), home))")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("No exchange rate yet. It converts once you're online.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if isPaid {
                Label("Added to Money", systemImage: "checkmark.circle.fill").foregroundStyle(Area.money.color)
            } else if costMinor > 0 {
                Toggle("Add to Money now (already paid)", isOn: $addToMoney)
            }
        } header: {
            Text("Cost")
        } footer: {
            Text("Planned costs count towards the trip budget. Add them to Money once you've paid.")
        }
    }

    private func choose(_ place: FoundPlace) {
        placeName = place.name
        address = place.address
        latitude = place.latitude
        longitude = place.longitude
        if title.isEmpty { title = place.name }
        search.query = ""
    }

    private func biasSearch(to trip: Trip) {
        if let center = trip.coordinate {
            search.region = MKCoordinateRegion(center: center, latitudinalMeters: 60_000, longitudinalMeters: 60_000)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        currency = home
        if let item {
            trip = item.trip
            day = item.day.startOfDay
            kind = item.kind
            title = item.title
            placeName = item.placeName
            address = item.address
            latitude = item.latitude
            longitude = item.longitude
            hasTime = item.startTime != nil
            if let start = item.startTime { time = start }
            duration = item.durationMinutes
            costText = item.costMinor > 0 ? MoneyFormat.editString(item.costMinor, item.costCurrency) : ""
            currency = item.costCurrency
            booking = item.booking
            notes = item.notes
        } else {
            trip = presetTrip ?? (trips.count == 1 ? trips.first : nil)
            if let trip {
                currency = trip.currencyCode
                day = presetDay?.startOfDay ?? (trip.isUnderway ? Date.now.startOfDay : trip.startDate.startOfDay)
            }
            if let presetPlace { choose(presetPlace) }
        }
        if let trip { biasSearch(to: trip) }
    }

    private func save() {
        guard let trip else { return }
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? placeName : title.trimmingCharacters(in: .whitespaces)
        let target: TripItem
        if let item {
            target = item
        } else {
            target = TripItem(day: day, kind: kind, title: finalTitle)
            context.insert(target)
            target.trip = trip
            target.sortOrder = trip.items?.count ?? 0
        }
        target.day = day.startOfDay
        target.kind = kind
        target.title = finalTitle
        target.placeName = placeName
        target.address = address
        target.latitude = latitude
        target.longitude = longitude
        target.startTime = hasTime ? day.at(timeOf: time) : nil
        target.durationMinutes = duration
        let currencyChanged = target.costCurrency != currency || target.costMinor != costMinor
        target.costMinor = costMinor
        target.costCurrency = currency
        if item == nil || currencyChanged {
            target.costRateToHome = rates.rate(from: currency, to: home) ?? (currency == home ? 1 : target.costRateToHome)
        }
        target.booking = booking
        target.notes = notes
        if addToMoney && !target.isPaid {
            target.recordPayment(in: context)
        }
        dismiss()
    }
}
