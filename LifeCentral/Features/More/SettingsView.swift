import SwiftUI

struct SettingsView: View {
    @Environment(ExchangeRates.self) private var rates
    @Environment(HealthService.self) private var health
    @Environment(BackupService.self) private var backup
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"
    @AppStorage(SettingsKey.weekStartsMonday) private var weekStartsMonday = true
    @AppStorage(SettingsKey.appLock) private var appLock = false
    @AppStorage(SettingsKey.documentsLock) private var documentsLock = false
    @AppStorage(SettingsKey.billReminderDays) private var billReminderDays = 3
    @AppStorage(SettingsKey.documentReminderMonths) private var documentReminderMonths = 3

    var body: some View {
        Form {
            Section {
                TextField("Your first name", text: $userName)
            } header: {
                Text("You")
            } footer: {
                Text("Used for the greeting on Today and when you share with friends.")
            }

            Section {
                NavigationLink {
                    CurrencyPicker(selection: $home)
                } label: {
                    ValueRow(label: "Home currency", value: "\(home) · \(CurrencyInfo.name(home))")
                }
                Toggle("Weeks start on Monday", isOn: $weekStartsMonday)
            } header: {
                Text("Money and dates")
            } footer: {
                Text("Spending in other currencies is converted to your home currency. Past entries keep the amount they were saved with.")
            }

            Section {
                Toggle("Face ID to open the app", isOn: Binding(get: { appLock }, set: { newValue in confirmFaceID { appLock = newValue } }))
                Toggle("Face ID for documents", isOn: Binding(get: { documentsLock }, set: { newValue in confirmFaceID { documentsLock = newValue } }))
            } header: {
                Text("Privacy")
            } footer: {
                Text("Everything is stored on this iPhone. Documents are encrypted and can't be read while the phone is locked.")
            }

            Section("Reminders") {
                Stepper("Bills: \(billReminderDays == 0 ? "on the day" : "\(billReminderDays) day\(billReminderDays == 1 ? "" : "s") before")",
                        value: $billReminderDays, in: 0...30)
                Stepper("Documents: \(documentReminderMonths) month\(documentReminderMonths == 1 ? "" : "s") before expiry",
                        value: $documentReminderMonths, in: 1...12)
                Button("Notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                }
            }

            Section {
                if !health.isAvailable {
                    Text("Not available on this device").foregroundStyle(.secondary)
                } else if health.isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(Area.health.color)
                    Button("Change what's shared") {
                        if let url = URL(string: "x-apple-health://") { UIApplication.shared.open(url) }
                    }
                } else {
                    Button("Connect Apple Health") { Task { await health.connect() } }
                }
            } header: {
                Text("Apple Health")
            } footer: {
                if health.isConnected {
                    Text("To change permissions, open Health, tap your picture, then Apps, then Life Central.")
                }
            }

            Section("Backup") {
                NavigationLink {
                    BackupView()
                } label: {
                    HStack {
                        Label("Encrypted iCloud backup", systemImage: "lock.icloud")
                        Spacer()
                        Text(backup.summaryText).foregroundStyle(backup.lastError == nil ? Color.secondary : Color.orange)
                    }
                }
            }

            Section {
                HStack {
                    Text("Exchange rates")
                    Spacer()
                    if rates.isLoading {
                        ProgressView()
                    } else {
                        Text(rates.updatedAt.map { "Updated \($0.formatted(.relative(presentation: .named)))" } ?? "Not loaded yet")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Update rates now") { Task { await rates.refresh() } }
                    .disabled(rates.isLoading)
                if let error = rates.lastError {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Life Central \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""). Rates from open.er-api.com, refreshed twice a day when online.")
            }
        }
        .navigationTitle("Settings")
        .onChange(of: home) { _, _ in Task { await rates.refresh() } }
    }

    /// Changing a Face ID setting needs Face ID first, so nobody else can switch it off.
    private func confirmFaceID(_ apply: @escaping () -> Void) {
        Task {
            if await FaceID.authenticate(reason: "Change Face ID settings") { apply() }
        }
    }
}
