import Foundation

/// Keys for small preferences kept in UserDefaults. Views read them with @AppStorage.
enum SettingsKey {
    static let homeCurrency = "homeCurrency"
    static let weekStartsMonday = "weekStartsMonday"
    static let appLock = "appLock"
    static let documentsLock = "documentsLock"
    static let billReminderDays = "billReminderDays"
    static let documentReminderMonths = "documentReminderMonths"
    static let healthConnected = "healthConnected"
    static let didSeedDefaults = "didSeedDefaults"
    static let userName = "userName"
    static let backupBookmark = "backupBookmark"
    static let backupFolderName = "backupFolderName"
    static let backupLastAt = "backupLastAt"
    static let backupLastSize = "backupLastSize"
    static let backupAutomatic = "backupAutomatic"
    static let backupID = "backupID"
    static let backupPasswordInICloud = "backupPasswordInICloud"
}

enum AppSettings {
    static var homeCurrency: String {
        UserDefaults.standard.string(forKey: SettingsKey.homeCurrency) ?? "GBP"
    }

    static var weekStartsMonday: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.weekStartsMonday) as? Bool ?? true
    }

    static var userName: String {
        UserDefaults.standard.string(forKey: SettingsKey.userName) ?? ""
    }
}
