import Foundation
import CryptoKit
import CommonCrypto
import Security
import SQLite3
import SwiftData
import UIKit

// MARK: - Format

/// What a backup folder holds. Only `backup.json` can be read without the
/// password, and it says nothing about what's inside.
///
///     Life Central Backup/
///       backup.json        salt, password check, date
///       index.lcb          list of files and settings (encrypted)
///       store-<id>.lcb     all app data (encrypted)
///       files/<hash>.lcb   each document and photo (encrypted)
struct BackupHeader: Codable, Sendable {
    var format = BackupHeader.formatName
    var version = 1
    /// The iPhone that writes to this backup, so two phones don't overwrite each other.
    var id: String
    var createdAt: Date
    var salt: Data
    var rounds: Int
    /// A known text encrypted with the key: opening it proves the password is right.
    var check: Data
    var appVersion: String

    static let formatName = "life-central-backup"
}

struct BackupIndex: Codable, Sendable {
    struct File: Codable, Hashable, Sendable {
        enum Kind: String, Codable, Sendable { case document, attachment }
        var kind: Kind
        /// Name on the phone.
        var name: String
        /// Name in the backup folder.
        var stored: String
        var size: Int
    }

    var createdAt: Date
    var storeFile: String
    var storeSize: Int
    var files: [File]
    /// Preferences such as home currency, as a property list.
    var settings: Data
    /// How many trips, workouts and so on, shown before restoring.
    var counts: [String: Int]

    var totalSize: Int { storeSize + files.reduce(0) { $0 + $1.size } }
}

enum BackupError: LocalizedError {
    case noPassword, noFolder, folderUnavailable, wrongPassword, notABackup, nestedFolder, newerVersion, otherDevice
    case damaged(String), snapshotFailed(String)

    var errorDescription: String? {
        switch self {
        case .noPassword: "Choose a backup password first."
        case .noFolder: "Choose a folder in iCloud Drive first."
        case .folderUnavailable: "The backup folder can't be reached. Check you're signed in to iCloud, or choose the folder again."
        case .wrongPassword: "That password doesn't open this backup."
        case .notABackup: "There's no Life Central backup in that folder."
        case .nestedFolder: "That's the backup itself. Choose the folder it sits in instead."
        case .newerVersion: "This backup was made by a newer version of Life Central. Update the app first."
        case .otherDevice: "Another iPhone backs up to this folder. Choose the folder again to restore from it or replace it."
        case .damaged(let detail): "Part of the backup can't be read (\(detail))."
        case .snapshotFailed(let detail): "Couldn't copy the app's data (\(detail))."
        }
    }
}

// MARK: - Encryption

enum BackupCrypto {
    static let rounds = 600_000
    static let checkText = Data("life-central-backup".utf8)

    static func newSalt() -> Data {
        SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    }

    /// PBKDF2-SHA256 turns the password into a 256-bit key. The high round count
    /// makes guessing passwords slow.
    static func key(password: String, salt: Data, rounds: Int) -> SymmetricKey? {
        let passwordData = Data(password.utf8)
        guard !passwordData.isEmpty else { return nil }
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) -> Int32 in
            salt.withUnsafeBytes { (saltBytes: UnsafeRawBufferPointer) -> Int32 in
                passwordData.withUnsafeBytes { (passwordBytes: UnsafeRawBufferPointer) -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self), passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(rounds),
                        out.baseAddress?.assumingMemoryBound(to: UInt8.self), 32)
                }
            }
        }
        return status == Int32(kCCSuccess) ? SymmetricKey(data: derived) : nil
    }

    /// AES-256-GCM. The file's name is sealed in too, so files can't be swapped around.
    static func seal(_ data: Data, name: String, key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key, authenticating: Data(name.utf8)).combined else {
            throw BackupError.damaged(name)
        }
        return combined
    }

    static func open(_ data: Data, name: String, key: SymmetricKey) throws -> Data {
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key, authenticating: Data(name.utf8))
        } catch {
            throw BackupError.damaged(name)
        }
    }

    /// The name a file gets in the backup folder, which doesn't give away what it is.
    static func storedName(kind: BackupIndex.File.Kind, name: String) -> String {
        let digest = SHA256.hash(data: Data("\(kind.rawValue)/\(name)".utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined() + ".lcb"
    }
}

/// The backup password lives in the Keychain so automatic backups can run.
/// In iCloud Keychain it also reaches a new iPhone, ready for restoring.
enum BackupPassword {
    private static let service = "com.lifecentral.backup"
    private static let account = "password"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ password: String, inICloudKeychain: Bool) -> Bool {
        delete()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: "Life Central backup password",
            kSecAttrSynchronizable as String: inICloudKeychain,
            kSecAttrAccessible as String: inICloudKeychain ? kSecAttrAccessibleAfterFirstUnlock : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(password.utf8),
        ]
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Files

/// File access for the backup folder. iCloud Drive can keep files online only,
/// so every read and write goes through a file coordinator, which downloads
/// files first and keeps iCloud in step.
enum CoordinatedFiles {
    static func read(_ url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(BackupError.folderUnavailable)
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            result = Result(catching: { try Data(contentsOf: readURL) })
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    static func write(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            result = Result(catching: { try data.write(to: writeURL, options: .atomic) })
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    static func createFolder(_ url: URL) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &coordinationError) { folderURL in
            result = Result(catching: { try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true) })
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    static func remove(_ url: URL) {
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { deleteURL in
            try? FileManager.default.removeItem(at: deleteURL)
        }
    }

    static func move(_ source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: source, options: .forMoving,
                                       writingItemAt: destination, options: .forReplacing,
                                       error: &coordinationError) { from, to in
            result = Result(catching: { try FileManager.default.moveItem(at: from, to: to) })
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }
}

enum StoreSnapshot {
    /// A single-file copy of the database, taken while the app keeps using it.
    /// SQLite's VACUUM INTO reads one moment in time, including changes still
    /// waiting in the write-ahead log.
    static func copy(of storeURL: URL, to destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        var handle: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db = handle else {
            sqlite3_close(handle)
            throw BackupError.snapshotFailed("open")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5000)
        let path = destination.path.replacingOccurrences(of: "'", with: "''")
        guard sqlite3_exec(db, "VACUUM INTO '\(path)'", nil, nil, nil) == SQLITE_OK else {
            throw BackupError.snapshotFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
}

// MARK: - Backing up and restoring

/// The slow part of backing up and restoring, run away from the main thread.
struct BackupEngine: Sendable {
    static let folderName = "Life Central Backup"

    let documentsFolder: URL
    let attachmentsFolder: URL
    let storeURL: URL
    let progress: @Sendable (String) -> Void

    static func backupFolder(in root: URL) -> URL {
        root.appendingPathComponent(folderName, isDirectory: true)
    }

    /// The header of the backup in `folder`, or nil if there isn't one.
    static func readHeader(in folder: URL) throws -> BackupHeader? {
        let data: Data
        do {
            data = try CoordinatedFiles.read(folder.appendingPathComponent("backup.json"))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
        guard let header = try? decoder.decode(BackupHeader.self, from: data), header.format == BackupHeader.formatName else {
            throw BackupError.notABackup
        }
        guard header.version <= 1 else { throw BackupError.newerVersion }
        return header
    }

    static func unlock(_ header: BackupHeader, password: String) throws -> SymmetricKey {
        guard let key = BackupCrypto.key(password: password, salt: header.salt, rounds: header.rounds),
              (try? BackupCrypto.open(header.check, name: "check", key: key)) == BackupCrypto.checkText
        else { throw BackupError.wrongPassword }
        return key
    }

    static func openIndex(in folder: URL, key: SymmetricKey) throws -> BackupIndex {
        let sealed = try CoordinatedFiles.read(folder.appendingPathComponent("index.lcb"))
        return try decoder.decode(BackupIndex.self, from: BackupCrypto.open(sealed, name: "index.lcb", key: key))
    }

    /// Writes a backup into `root`. Files already backed up are skipped, so
    /// after the first run only the data and new documents are uploaded.
    func backUp(to root: URL, password: String, deviceID: String, replaceOther: Bool,
                settings: Data, counts: [String: Int]) throws -> (header: BackupHeader, index: BackupIndex) {
        let folder = Self.backupFolder(in: root)
        var previous: (header: BackupHeader, key: SymmetricKey, index: BackupIndex)?
        if let header = try Self.readHeader(in: folder) {
            if header.id != deviceID && !replaceOther { throw BackupError.otherDevice }
            if header.id == deviceID, let key = try? Self.unlock(header, password: password),
               let index = try? Self.openIndex(in: folder, key: key) {
                previous = (header, key, index)
            }
        }

        let salt = previous?.header.salt ?? BackupCrypto.newSalt()
        let rounds = previous?.header.rounds ?? BackupCrypto.rounds
        let key: SymmetricKey
        if let previous {
            key = previous.key
        } else {
            progress("Securing with your password…")
            guard let derived = BackupCrypto.key(password: password, salt: salt, rounds: rounds) else { throw BackupError.noPassword }
            key = derived
        }

        // A first backup, or one with a new password, is written beside the old
        // one and swapped in at the end, so there's always one complete backup.
        let target = previous == nil ? root.appendingPathComponent("\(Self.folderName) (in progress)", isDirectory: true) : folder
        if previous == nil { CoordinatedFiles.remove(target) }
        try CoordinatedFiles.createFolder(target.appendingPathComponent("files", isDirectory: true))

        // The data first, so every document it mentions is copied below.
        progress("Copying your data…")
        let snapshot = FileManager.default.temporaryDirectory.appendingPathComponent("backup-snapshot.sqlite")
        try StoreSnapshot.copy(of: storeURL, to: snapshot)
        defer { try? FileManager.default.removeItem(at: snapshot) }
        let storeData = try Data(contentsOf: snapshot)

        let known = Set(previous?.index.files.map(\.stored) ?? [])
        let local = localFiles()
        var files: [BackupIndex.File] = []
        for (number, entry) in local.enumerated() {
            let stored = BackupCrypto.storedName(kind: entry.kind, name: entry.name)
            files.append(.init(kind: entry.kind, name: entry.name, stored: stored, size: entry.size))
            guard !known.contains(stored) else { continue }
            progress("Encrypting files: \(number + 1) of \(local.count)")
            let data = try Data(contentsOf: entry.url)
            try CoordinatedFiles.write(BackupCrypto.seal(data, name: stored, key: key),
                                       to: target.appendingPathComponent("files/\(stored)"))
        }

        progress("Encrypting your data…")
        let storeFile = "store-\(UUID().uuidString.prefix(8).lowercased()).lcb"
        try CoordinatedFiles.write(BackupCrypto.seal(storeData, name: storeFile, key: key),
                                   to: target.appendingPathComponent(storeFile))

        // Until the index is replaced, the old backup is still whole.
        let index = BackupIndex(createdAt: .now, storeFile: storeFile, storeSize: storeData.count,
                                files: files, settings: settings, counts: counts)
        try CoordinatedFiles.write(BackupCrypto.seal(Self.encoder.encode(index), name: "index.lcb", key: key),
                                   to: target.appendingPathComponent("index.lcb"))
        let header = BackupHeader(id: deviceID, createdAt: index.createdAt, salt: salt, rounds: rounds,
                                  check: try BackupCrypto.seal(BackupCrypto.checkText, name: "check", key: key),
                                  appVersion: Self.appVersion)
        try CoordinatedFiles.write(Self.encoder.encode(header), to: target.appendingPathComponent("backup.json"))

        progress("Tidying up…")
        if let previous {
            CoordinatedFiles.remove(folder.appendingPathComponent(previous.index.storeFile))
            let keep = Set(files.map(\.stored))
            for old in previous.index.files where !keep.contains(old.stored) {
                CoordinatedFiles.remove(folder.appendingPathComponent("files/\(old.stored)"))
            }
        } else {
            CoordinatedFiles.remove(folder)
            try CoordinatedFiles.move(target, to: folder)
        }
        return (header, index)
    }

    /// Downloads and decrypts a backup into a waiting folder. The app swaps it in
    /// the next time it opens, before it touches its data.
    func stageRestore(from folder: URL, key: SymmetricKey, index: BackupIndex) throws {
        let fm = FileManager.default
        let partial = BackupRestore.pendingFolder.appendingPathExtension("partial")
        try? fm.removeItem(at: partial)
        let documents = partial.appendingPathComponent("Documents", isDirectory: true)
        let attachments = partial.appendingPathComponent("Attachments", isDirectory: true)
        try fm.createDirectory(at: documents, withIntermediateDirectories: true,
                               attributes: [.protectionKey: FileProtectionType.complete])
        try fm.createDirectory(at: attachments, withIntermediateDirectories: true)

        progress("Downloading your data…")
        let storeFile = Self.safeName(index.storeFile)
        let store = try BackupCrypto.open(CoordinatedFiles.read(folder.appendingPathComponent(storeFile)), name: storeFile, key: key)
        try store.write(to: partial.appendingPathComponent(BackupRestore.stagedStoreName), options: .atomic)

        for (number, file) in index.files.enumerated() {
            progress("Downloading files: \(number + 1) of \(index.files.count)")
            let stored = Self.safeName(file.stored)
            let data = try BackupCrypto.open(CoordinatedFiles.read(folder.appendingPathComponent("files/\(stored)")), name: stored, key: key)
            switch file.kind {
            case .document:
                try data.write(to: documents.appendingPathComponent(Self.safeName(file.name)), options: [.atomic, .completeFileProtection])
            case .attachment:
                try data.write(to: attachments.appendingPathComponent(Self.safeName(file.name)), options: .atomic)
            }
        }
        try index.settings.write(to: partial.appendingPathComponent("settings.plist"))

        try? fm.removeItem(at: BackupRestore.pendingFolder)
        try fm.moveItem(at: partial, to: BackupRestore.pendingFolder)
    }

    private struct LocalFile {
        var kind: BackupIndex.File.Kind
        var name: String
        var url: URL
        var size: Int
    }

    private func localFiles() -> [LocalFile] {
        func list(_ folder: URL, _ kind: BackupIndex.File.Kind) -> [LocalFile] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            return names.filter { !$0.hasPrefix(".") }.sorted().map { name in
                let url = folder.appendingPathComponent(name)
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return LocalFile(kind: kind, name: name, url: url, size: size)
            }
        }
        return list(documentsFolder, .document) + list(attachmentsFolder, .attachment)
    }

    /// Names from the backup never reach outside the folder they're meant for.
    private static func safeName(_ name: String) -> String {
        let last = URL(fileURLWithPath: name).lastPathComponent
        return last == ".." || last == "." || last.isEmpty ? "unnamed" : last
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Swaps a downloaded backup in at launch, before the data store opens.
enum BackupRestore {
    static let stagedStoreName = "default.store"

    static var pendingFolder: URL {
        URL.applicationSupportDirectory.appendingPathComponent("PendingRestore", isDirectory: true)
    }

    /// Where SwiftData keeps large photos (receipts, thumbnails) outside the database.
    static func attachmentsFolder(for storeURL: URL) -> URL {
        let name = storeURL.deletingPathExtension().lastPathComponent
        return storeURL.deletingLastPathComponent()
            .appendingPathComponent(".\(name)_SUPPORT", isDirectory: true)
            .appendingPathComponent("_EXTERNAL_DATA", isDirectory: true)
    }

    static func applyPendingIfNeeded(storeURL: URL) {
        let fm = FileManager.default
        let pending = pendingFolder
        let stagedStore = pending.appendingPathComponent(stagedStoreName)
        guard fm.fileExists(atPath: stagedStore.path) else { return }

        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        let attachments = attachmentsFolder(for: storeURL)
        try? fm.removeItem(at: attachments.deletingLastPathComponent())
        do {
            try fm.moveItem(at: stagedStore, to: storeURL)
        } catch {
            // Leave everything staged and try again next launch.
            return
        }
        try? fm.createDirectory(at: attachments.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.moveItem(at: pending.appendingPathComponent("Attachments"), to: attachments)

        let documents = URL.applicationSupportDirectory.appendingPathComponent("Documents", isDirectory: true)
        try? fm.removeItem(at: documents)
        try? fm.moveItem(at: pending.appendingPathComponent("Documents"), to: documents)

        if let data = try? Data(contentsOf: pending.appendingPathComponent("settings.plist")),
           let settings = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            for (key, value) in settings where BackupService.backedUpSettings.contains(key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        // The restored data already has its categories and starter workouts.
        UserDefaults.standard.set(true, forKey: SettingsKey.didSeedDefaults)
        try? fm.removeItem(at: pending)
    }
}

// MARK: - Service

struct FoundBackup: Sendable {
    /// The "Life Central Backup" folder.
    let folder: URL
    /// The folder picked in Files.
    let root: URL
    let header: BackupHeader
    /// The backup sits inside the picked folder, so this iPhone can keep backing up there.
    let canContinue: Bool
}

/// CryptoKit's key type isn't marked Sendable on every SDK; it's immutable, so it's safe to pass along.
struct UnlockedBackup: @unchecked Sendable {
    let key: SymmetricKey
    let index: BackupIndex
}

/// Encrypted backup to a folder in iCloud Drive.
///
/// The app has no iCloud space of its own (that needs a paid Apple developer
/// account), so it writes into a folder you pick once in Files. Everything is
/// encrypted on the phone with your backup password before it's written, so
/// neither Apple nor anyone with your iCloud login can read it.
@MainActor
@Observable
final class BackupService {
    static let shared = BackupService()

    /// Preferences that travel with a backup. Per-phone ones, like Apple
    /// Health access and the backup folder itself, stay behind.
    nonisolated static let backedUpSettings: Set<String> = [
        SettingsKey.userName, SettingsKey.homeCurrency, SettingsKey.weekStartsMonday,
        SettingsKey.appLock, SettingsKey.documentsLock,
        SettingsKey.billReminderDays, SettingsKey.documentReminderMonths,
    ]

    private(set) var folderName = UserDefaults.standard.string(forKey: SettingsKey.backupFolderName)
    private(set) var lastBackupAt = UserDefaults.standard.object(forKey: SettingsKey.backupLastAt) as? Date
    private(set) var lastBackupSize = UserDefaults.standard.integer(forKey: SettingsKey.backupLastSize)
    private(set) var isAutomatic = UserDefaults.standard.object(forKey: SettingsKey.backupAutomatic) as? Bool ?? true
    private(set) var hasPassword = BackupPassword.read() != nil
    private(set) var isWorking = false
    private(set) var status = ""
    private(set) var lastError: String?
    /// A restore has been downloaded and waits for the app to reopen.
    private(set) var isRestoreStaged = false

    @ObservationIgnored private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    private init() {}

    var isConfigured: Bool { hasPassword && folderName != nil }

    var summaryText: String {
        guard isConfigured else { return "Off" }
        guard let lastBackupAt else { return "Not yet" }
        return lastBackupAt.formatted(.relative(presentation: .named))
    }

    var passwordInICloudKeychain: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.backupPasswordInICloud) as? Bool ?? true
    }

    /// Identifies this iPhone's backup. A restored iPhone takes over the id of
    /// the backup it came from.
    var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: SettingsKey.backupID) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: SettingsKey.backupID)
        return id
    }

    // MARK: Setup

    func setPassword(_ password: String, inICloudKeychain: Bool) {
        var savedInICloud = inICloudKeychain
        if !BackupPassword.save(password, inICloudKeychain: inICloudKeychain) {
            savedInICloud = false
            BackupPassword.save(password, inICloudKeychain: false)
        }
        UserDefaults.standard.set(savedInICloud, forKey: SettingsKey.backupPasswordInICloud)
        hasPassword = BackupPassword.read() != nil
    }

    func setAutomatic(_ isOn: Bool) {
        isAutomatic = isOn
        UserDefaults.standard.set(isOn, forKey: SettingsKey.backupAutomatic)
    }

    /// Remembers a folder picked in Files, so later backups can reach it.
    func setFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData()
        let name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) ?? url.lastPathComponent
        UserDefaults.standard.set(bookmark, forKey: SettingsKey.backupBookmark)
        UserDefaults.standard.set(name, forKey: SettingsKey.backupFolderName)
        UserDefaults.standard.removeObject(forKey: SettingsKey.backupLastAt)
        folderName = name
        lastBackupAt = nil
    }

    func report(_ error: Error) {
        lastError = Self.message(for: error)
    }

    // MARK: Backing up

    func backUpNow(context: ModelContext, replaceOther: Bool = false) async {
        guard !isWorking, !isRestoreStaged else { return }
        isWorking = true
        lastError = nil
        status = "Starting…"
        defer {
            isWorking = false
            status = ""
        }
        do {
            guard let password = BackupPassword.read() else { throw BackupError.noPassword }
            let root = try resolveFolder()
            let accessing = root.startAccessingSecurityScopedResource()
            defer { if accessing { root.stopAccessingSecurityScopedResource() } }

            try? context.save()
            let engine = makeEngine()
            let deviceID = self.deviceID
            let settings = Self.settingsSnapshot()
            let counts = Self.counts(in: context)
            let result = try await Task.detached(priority: .utility) {
                try engine.backUp(to: root, password: password, deviceID: deviceID, replaceOther: replaceOther,
                                  settings: settings, counts: counts)
            }.value
            lastBackupAt = result.index.createdAt
            lastBackupSize = result.index.totalSize
            UserDefaults.standard.set(lastBackupAt, forKey: SettingsKey.backupLastAt)
            UserDefaults.standard.set(lastBackupSize, forKey: SettingsKey.backupLastSize)
        } catch {
            lastError = Self.message(for: error)
        }
    }

    /// Called when the app goes to the background. Backs up at most once a day.
    func backUpIfDue(context: ModelContext) {
        guard isAutomatic, isConfigured, !isWorking, !isRestoreStaged else { return }
        if let lastBackupAt, Date.now.timeIntervalSince(lastBackupAt) < 20 * 3600 { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Life Central backup") { [weak self] in
            self?.endBackgroundTask()
        }
        Task {
            await backUpNow(context: context)
            endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    // MARK: Restoring

    /// Looks for a backup in a folder picked in Files: either the backup itself
    /// or the folder it sits in.
    func findBackup(in picked: URL) async throws -> FoundBackup {
        let accessing = picked.startAccessingSecurityScopedResource()
        defer { if accessing { picked.stopAccessingSecurityScopedResource() } }
        return try await Task.detached(priority: .userInitiated) {
            let inner = BackupEngine.backupFolder(in: picked)
            if let header = try BackupEngine.readHeader(in: inner) {
                return FoundBackup(folder: inner, root: picked, header: header, canContinue: true)
            }
            if let header = try BackupEngine.readHeader(in: picked) {
                return FoundBackup(folder: picked, root: picked, header: header, canContinue: false)
            }
            throw BackupError.notABackup
        }.value
    }

    func unlock(_ found: FoundBackup, password: String) async throws -> UnlockedBackup {
        let accessing = found.root.startAccessingSecurityScopedResource()
        defer { if accessing { found.root.stopAccessingSecurityScopedResource() } }
        return try await Task.detached(priority: .userInitiated) {
            let key = try BackupEngine.unlock(found.header, password: password)
            return UnlockedBackup(key: key, index: try BackupEngine.openIndex(in: found.folder, key: key))
        }.value
    }

    /// Downloads the backup, ready to replace everything when the app reopens.
    @discardableResult
    func restore(_ found: FoundBackup, unlocked: UnlockedBackup, password: String, keepInICloudKeychain: Bool) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        lastError = nil
        status = "Starting…"
        defer {
            isWorking = false
            status = ""
        }
        let accessing = found.root.startAccessingSecurityScopedResource()
        defer { if accessing { found.root.stopAccessingSecurityScopedResource() } }
        let engine = makeEngine()
        do {
            try await Task.detached(priority: .userInitiated) {
                try engine.stageRestore(from: found.folder, key: unlocked.key, index: unlocked.index)
            }.value
        } catch {
            lastError = Self.message(for: error)
            return false
        }

        // This iPhone carries on with the same backup.
        setPassword(password, inICloudKeychain: keepInICloudKeychain)
        UserDefaults.standard.set(found.header.id, forKey: SettingsKey.backupID)
        if found.canContinue, (try? setFolder(found.root)) != nil {
            lastBackupAt = found.header.createdAt
            UserDefaults.standard.set(lastBackupAt, forKey: SettingsKey.backupLastAt)
        }
        isRestoreStaged = true
        return true
    }

    // MARK: Helpers

    private func resolveFolder() throws -> URL {
        guard let bookmark = UserDefaults.standard.data(forKey: SettingsKey.backupBookmark) else { throw BackupError.noFolder }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            throw BackupError.folderUnavailable
        }
        if isStale {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData() {
                UserDefaults.standard.set(fresh, forKey: SettingsKey.backupBookmark)
            }
        }
        return url
    }

    private func makeEngine() -> BackupEngine {
        BackupEngine(documentsFolder: DocumentStore.folder,
                     attachmentsFolder: BackupRestore.attachmentsFolder(for: AppSchema.storeURL),
                     storeURL: AppSchema.storeURL,
                     progress: { [weak self] text in
                         Task { @MainActor in self?.status = text }
                     })
    }

    private static func settingsSnapshot() -> Data {
        var values: [String: Any] = [:]
        for key in backedUpSettings {
            if let value = UserDefaults.standard.object(forKey: key) { values[key] = value }
        }
        return (try? PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)) ?? Data()
    }

    private static func counts(in context: ModelContext) -> [String: Int] {
        func count<T: PersistentModel>(_ type: T.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
        }
        return [
            "Money entries": count(MoneyEntry.self),
            "Bills": count(Bill.self),
            "Trips": count(Trip.self),
            "Workouts done": count(WorkoutSession.self),
            "Documents": count(Document.self),
            "Habits": count(Habit.self),
            "Tasks": count(TodoItem.self),
            "Recipes": count(Recipe.self),
        ]
    }

    private static func message(for error: Error) -> String {
        if let error = error as? BackupError { return error.errorDescription ?? "Backup failed." }
        if let error = error as? CocoaError {
            switch error.code {
            case .fileWriteOutOfSpace: return "There isn't enough space in iCloud Drive."
            case .fileReadNoPermission, .fileWriteNoPermission: return BackupError.folderUnavailable.errorDescription ?? ""
            default: break
            }
        }
        return "Backup failed: \(error.localizedDescription)"
    }
}
