import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(BackupService.self) private var backup
    @Environment(\.modelContext) private var context
    @State private var showPassword = false
    @State private var pickFolder = false
    @State private var restore: RestoreRequest?
    @State private var conflict: FoundBackup?
    @State private var revealedPassword: String?

    private let color = Area.settings.color

    var body: some View {
        Form {
            Section { status }

            if backup.isConfigured {
                Section {
                    Toggle("Back up automatically", isOn: Binding(get: { backup.isAutomatic }, set: { backup.setAutomatic($0) }))
                    ValueRow(label: "Folder", value: backup.folderName ?? "")
                    Button("Choose a different folder") { pickFolder = true }
                } footer: {
                    Text("Once a day, when you leave the app. Only new documents and photos are uploaded each time.")
                }
                Section {
                    Button("Change password") { showPassword = true }
                    if let revealedPassword {
                        Text(revealedPassword).font(.body.monospaced()).textSelection(.enabled)
                    } else {
                        Button("Show password") { reveal() }
                    }
                } header: {
                    Text("Password")
                } footer: {
                    Text(backup.passwordInICloudKeychain
                         ? "Kept in your iCloud Keychain, so a new iPhone signed in to your Apple ID can restore without typing it."
                         : "Kept on this iPhone only. Write it down somewhere safe: you'll need it on a new iPhone.")
                }
            } else {
                setup
            }

            Section {
                Button { restore = RestoreRequest(folder: nil) } label: {
                    Label("Restore from a backup", systemImage: "arrow.counterclockwise.icloud")
                }
            } footer: {
                Text("For a new iPhone, or to go back to an earlier copy. It replaces everything in the app.")
            }

            Section {
                Label("Encrypted on this iPhone with your password before anything is saved to iCloud Drive (AES-256). Apple can't read it, and nor can anyone who gets into your iCloud account.", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(color)
        .navigationTitle("Backup")
        .sheet(isPresented: $showPassword) {
            BackupPasswordSheet(isChange: backup.hasPassword) {
                if backup.isConfigured { Task { await backup.backUpNow(context: context) } }
            }
        }
        .sheet(item: $restore) { request in
            RestoreBackupSheet(initialFolder: request.folder)
        }
        .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): Task { await choose(url) }
            case .failure(let error): backup.report(error)
            }
        }
        .confirmationDialog("This folder already has a backup",
                            isPresented: Binding(get: { conflict != nil }, set: { if !$0 { conflict = nil } }),
                            titleVisibility: .visible, presenting: conflict) { found in
            Button("Restore from it") { restore = RestoreRequest(folder: found.root) }
            Button("Replace it with this iPhone's data", role: .destructive) {
                do {
                    try backup.setFolder(found.root)
                    Task { await backup.backUpNow(context: context, replaceOther: true) }
                } catch {
                    backup.report(error)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { found in
            Text("Made \(found.header.createdAt.formatted(date: .abbreviated, time: .shortened)) on another iPhone. Replacing it can't be undone.")
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconChip(symbol: backup.lastError == nil ? "lock.icloud" : "exclamationmark.icloud",
                         color: backup.lastError == nil ? color : .orange, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline).font(.headline)
                    if !detail.isEmpty {
                        Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if backup.isWorking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(backup.status).font(.subheadline).foregroundStyle(.secondary)
                }
            } else if let error = backup.lastError {
                Text(error).font(.subheadline).foregroundStyle(.orange)
            }
            if backup.isConfigured {
                Button {
                    Task { await backup.backUpNow(context: context) }
                } label: {
                    Text("Back up now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(backup.isWorking)
            }
        }
        .padding(.vertical, 6)
    }

    private var headline: String {
        guard backup.isConfigured else { return "Not set up yet" }
        guard let last = backup.lastBackupAt else { return "Not backed up yet" }
        return "Backed up \(last.formatted(.relative(presentation: .named)))"
    }

    private var detail: String {
        guard backup.isConfigured else { return "Two steps: a password, then a folder in iCloud Drive." }
        guard backup.lastBackupAt != nil else { return "In \(backup.folderName ?? "iCloud Drive")" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(backup.lastBackupSize), countStyle: .file)
        return "\(size) in \(backup.folderName ?? "iCloud Drive")"
    }

    private var setup: some View {
        Section {
            Button { showPassword = true } label: {
                step(1, "Choose a backup password", done: backup.hasPassword)
            }
            Button { pickFolder = true } label: {
                step(2, "Choose a folder in iCloud Drive", done: backup.folderName != nil)
            }
            .disabled(!backup.hasPassword)
        } header: {
            Text("Set up")
        } footer: {
            Text("In Files, tap iCloud Drive, make a new folder (for example Life Central), open it and tap Open. The first backup starts straight away.")
        }
    }

    private func step(_ number: Int, _ title: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(done ? color : color.opacity(0.14)).frame(width: 28, height: 28)
                if done {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.subheadline.weight(.bold)).foregroundStyle(color)
                }
            }
            Text(title).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
    }

    /// A folder with another iPhone's backup in it gets a choice before anything is overwritten.
    private func choose(_ url: URL) async {
        if let found = try? await backup.findBackup(in: url) {
            guard found.canContinue else {
                backup.report(BackupError.nestedFolder)
                return
            }
            if found.header.id != backup.deviceID {
                conflict = found
                return
            }
        }
        do {
            try backup.setFolder(url)
            await backup.backUpNow(context: context)
        } catch {
            backup.report(error)
        }
    }

    private func reveal() {
        Task {
            if await FaceID.authenticate(reason: "Show your backup password") {
                revealedPassword = BackupPassword.read()
            }
        }
    }
}

private struct RestoreRequest: Identifiable {
    let id = UUID()
    let folder: URL?
}

struct BackupPasswordSheet: View {
    var isChange = false
    var onSaved: () -> Void = {}

    @Environment(BackupService.self) private var backup
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var repeated = ""
    @State private var inICloudKeychain = true

    private var problem: String? {
        if password.count < 8 { return "Use at least 8 characters." }
        if password != repeated { return "The two passwords don't match." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Type it again", text: $repeated)
                        .textContentType(.newPassword)
                } footer: {
                    if !password.isEmpty, let problem { Text(problem).foregroundStyle(.orange) }
                }
                Section {
                    Toggle("Keep in iCloud Keychain", isOn: $inICloudKeychain)
                } footer: {
                    Text("Your iCloud Keychain is end-to-end encrypted. With this on, a new iPhone can restore without you typing the password.")
                }
                Section {
                    Label("If the password is lost, the backup can't be opened. Nobody can reset it.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                    if isChange {
                        Label("Changing it re-encrypts the whole backup, so the next one takes longer.", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                    }
                }
            }
            .tint(Area.settings.color)
            .navigationTitle(isChange ? "Change password" : "Backup password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        backup.setPassword(password, inICloudKeychain: inICloudKeychain)
                        dismiss()
                        onSaved()
                    }
                    .disabled(problem != nil)
                    .fontWeight(.bold)
                }
            }
            .onAppear { inICloudKeychain = backup.passwordInICloudKeychain }
        }
    }
}

struct RestoreBackupSheet: View {
    var initialFolder: URL?

    @Environment(BackupService.self) private var backup
    @Environment(\.dismiss) private var dismiss
    @State private var found: FoundBackup?
    @State private var unlocked: UnlockedBackup?
    @State private var password = ""
    @State private var keepInICloudKeychain = true
    @State private var pickFolder = false
    @State private var isChecking = false
    @State private var error: String?
    @State private var confirmReplace = false

    var body: some View {
        NavigationStack {
            Form {
                if let found, let unlocked {
                    summary(found, unlocked)
                } else if let found {
                    Section {
                        SecureField("Backup password", text: $password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .onSubmit { open(found) }
                        Button {
                            open(found)
                        } label: {
                            HStack {
                                Text("Unlock")
                                if isChecking { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(password.isEmpty || isChecking)
                    } header: {
                        Text("Backup from \(found.header.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    } footer: {
                        Text("The password you chose when you set up backups.")
                    }
                } else {
                    Section {
                        Button {
                            pickFolder = true
                        } label: {
                            HStack {
                                Label("Choose the backup folder", systemImage: "folder")
                                if isChecking { Spacer(); ProgressView() }
                            }
                        }
                    } footer: {
                        Text("Pick the folder in iCloud Drive you back up to. It holds a folder called Life Central Backup.")
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(.orange) }
                }
            }
            .tint(Area.settings.color)
            .navigationTitle("Restore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .interactiveDismissDisabled(backup.isWorking)
            .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let url): look(in: url)
                case .failure(let failure): error = failure.localizedDescription
                }
            }
            .confirmationDialog("Replace everything in Life Central?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace with the backup", role: .destructive) { restore() }
            } message: {
                Text("What's in the app now is removed and the backup takes its place.")
            }
            .onAppear {
                password = BackupPassword.read() ?? ""
                keepInICloudKeychain = backup.passwordInICloudKeychain
                if let initialFolder, found == nil { look(in: initialFolder) }
            }
        }
    }

    private func summary(_ found: FoundBackup, _ unlocked: UnlockedBackup) -> some View {
        Group {
            Section {
                ValueRow(label: "Made", value: found.header.createdAt.formatted(date: .abbreviated, time: .shortened))
                ValueRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(unlocked.index.totalSize), countStyle: .file))
                ForEach(unlocked.index.counts.sorted(by: { $0.key < $1.key }).filter { $0.value > 0 }, id: \.key) { item in
                    ValueRow(label: item.key, value: item.value.formatted())
                }
            } header: {
                Text("In this backup")
            }
            Section {
                Toggle("Keep password in iCloud Keychain", isOn: $keepInICloudKeychain)
            } footer: {
                Text(found.canContinue ? "This iPhone will carry on backing up to the same folder." : "Choose a backup folder afterwards to keep backing up.")
            }
            Section {
                if backup.isWorking {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(backup.status).foregroundStyle(.secondary)
                    }
                } else {
                    Button("Restore this backup", role: .destructive) { confirmReplace = true }
                }
                if let message = backup.lastError {
                    Text(message).foregroundStyle(.orange)
                }
            } footer: {
                Text("Documents and photos download from iCloud first, so keep the app open until it's done.")
            }
        }
    }

    private func look(in url: URL) {
        error = nil
        isChecking = true
        Task {
            do {
                found = try await backup.findBackup(in: url)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isChecking = false
        }
    }

    private func open(_ found: FoundBackup) {
        guard !password.isEmpty, !isChecking else { return }
        error = nil
        isChecking = true
        Task {
            do {
                unlocked = try await backup.unlock(found, password: password)
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isChecking = false
        }
    }

    private func restore() {
        guard let found, let unlocked else { return }
        Task {
            if await backup.restore(found, unlocked: unlocked, password: password, keepInICloudKeychain: keepInICloudKeychain) {
                dismiss()
            }
        }
    }
}

/// Covers the app once a restore is downloaded, until it's reopened.
struct RestoreReadyView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                IconChip(symbol: "checkmark.icloud", color: Area.settings.color, size: 64)
                Text("Backup downloaded").font(.title2.weight(.bold))
                Text("Close Life Central and open it again to finish. Swipe up from the bottom of the screen and pause, then swipe Life Central away.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("The app can't swap its data while it's using it.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(32)
        }
    }
}
