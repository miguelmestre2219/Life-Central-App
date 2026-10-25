import SwiftUI
import SwiftData
import QuickLook

/// Covers Documents with Face ID when "Face ID for documents" is on.
struct DocumentsLock<Content: View>: View {
    @ViewBuilder let content: Content
    @AppStorage(SettingsKey.documentsLock) private var documentsLock = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false

    var body: some View {
        content
            .overlay {
                if documentsLock && !unlocked {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        VStack(spacing: 14) {
                            Image(systemName: "lock.doc").font(.system(size: 44)).foregroundStyle(.secondary)
                            Text("Documents are locked").font(.headline)
                            Button("Unlock") { unlock() }
                                .buttonStyle(.borderedProminent)
                                .tint(Area.documents.color)
                        }
                    }
                }
            }
            .task { if documentsLock && !unlocked { unlock() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { unlocked = false }
            }
    }

    private func unlock() {
        Task { unlocked = await FaceID.authenticate(reason: "Open your documents") }
    }
}

struct DocumentsView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Document.createdAt, order: .reverse) private var documents: [Document]
    @State private var query = ""

    private let color = Area.documents.color

    private var folders: [String] {
        var list = DocumentFolder.defaults
        for name in documents.map(\.folder) where !list.contains(name) { list.append(name) }
        return list
    }

    private var expiring: [Document] {
        documents.filter(\.isExpiringSoon).sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    private var results: [Document] {
        documents.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.notes.localizedCaseInsensitiveContains(query)
                || $0.recognizedText.localizedCaseInsensitiveContains(query) || $0.folder.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        DocumentsLock {
            ScrollView {
                VStack(spacing: 16) {
                    if !query.isEmpty {
                        VStack(spacing: 0) {
                            if results.isEmpty {
                                Text("Nothing matches \"\(query)\".").font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
                            }
                            ForEach(results) { DocumentRow(document: $0) }
                        }
                        .card()
                    } else {
                        if !expiring.isEmpty { expiringCard }
                        folderGrid
                        if !documents.isEmpty { recent }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 90)
            }
            .screenBackground()
            .overlay(alignment: .bottom) {
                FloatingAddButton(title: "Add document", color: color) { router.present(.document(folder: nil)) }
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle("Documents")
        .searchable(text: $query, prompt: "Search titles and text inside")
    }

    private var expiringCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "Expiring soon", color: .orange)
            ForEach(expiring) { DocumentRow(document: $0) }
        }
        .card()
    }

    private var folderGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(folders, id: \.self) { folder in
                NavigationLink(value: Route.documentFolder(folder)) {
                    HStack(spacing: 10) {
                        IconChip(symbol: DocumentFolder.icon(folder), color: color, size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(folder).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text("\(documents.filter { $0.folder == folder }.count)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .card(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: "Recently added")
            ForEach(documents.prefix(5)) { DocumentRow(document: $0) }
        }
        .card()
    }
}

struct DocumentRow: View {
    let document: Document

    var body: some View {
        NavigationLink(value: Route.document(document)) {
            HStack(spacing: 12) {
                DocumentThumbnail(document: document, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(document.isExpiringSoon ? .orange : .secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detail: String {
        var parts = [document.folder]
        if let expires = document.expiresAt {
            parts.append(expires < .now ? "Expired \(expires.formatted(date: .abbreviated, time: .omitted))"
                                        : "Expires \(expires.formatted(date: .abbreviated, time: .omitted))")
        } else {
            parts.append(document.kindLabel)
        }
        return parts.joined(separator: " · ")
    }
}

struct DocumentThumbnail: View {
    let document: Document
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = document.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "doc.text").foregroundStyle(Area.documents.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Area.documents.tint)
            }
        }
        .frame(width: size, height: size * 1.25)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
        .accessibilityHidden(true)
    }
}

struct DocumentFolderView: View {
    let folder: String

    @Environment(AppRouter.self) private var router
    @Query(sort: \Document.title) private var all: [Document]

    private var documents: [Document] { all.filter { $0.folder == folder } }

    var body: some View {
        DocumentsLock {
            List {
                if documents.isEmpty {
                    Text("Nothing in \(folder) yet.").foregroundStyle(.secondary)
                }
                ForEach(documents) { DocumentRow(document: $0) }
            }
        }
        .navigationTitle(folder)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.document(folder: folder)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add document")
            }
        }
    }
}

struct DocumentDetailView: View {
    @Bindable var document: Document

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allDocuments: [Document]
    @State private var previewURL: URL?
    @State private var shareURL: URL?
    @State private var confirmDelete = false
    @State private var showText = false

    private let color = Area.documents.color

    private var folders: [String] {
        var list = DocumentFolder.defaults
        for name in allDocuments.map(\.folder) where !list.contains(name) { list.append(name) }
        return list
    }

    var body: some View {
        DocumentsLock {
            Form {
                Section {
                    Button { previewURL = DocumentStore.shareableCopy(of: document) } label: {
                        HStack(spacing: 14) {
                            DocumentThumbnail(document: document, size: 80)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open").font(.headline)
                                Text("\(document.kindLabel) · \(document.pageCount) page\(document.pageCount == 1 ? "" : "s")")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    TextField("Title", text: $document.title)
                    Picker("Folder", selection: $document.folder) {
                        ForEach(folders, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    Toggle("Has an expiry date", isOn: Binding(
                        get: { document.expiresAt != nil },
                        set: { document.expiresAt = $0 ? (document.expiresAt ?? Date.now.adding(months: 12)) : nil }))
                    if document.expiresAt != nil {
                        DatePicker("Expires", selection: Binding(get: { document.expiresAt ?? .now }, set: { document.expiresAt = $0 }),
                                   displayedComponents: .date)
                        Stepper("Remind me \(document.remindDaysBefore / 30) month\(document.remindDaysBefore / 30 == 1 ? "" : "s") before",
                                value: Binding(get: { document.remindDaysBefore / 30 }, set: { document.remindDaysBefore = $0 * 30 }), in: 1...12)
                    }
                    TextField("Notes", text: $document.notes, axis: .vertical)
                }

                if document.trip != nil || document.bill != nil {
                    Section("Linked to") {
                        if let trip = document.trip {
                            NavigationLink(value: Route.trip(trip)) { Label(trip.name, systemImage: "airplane") }
                        }
                        if let item = document.tripItem {
                            Label(item.title, systemImage: item.kind.icon)
                        }
                        if let bill = document.bill {
                            NavigationLink(value: Route.bills) { Label(bill.name, systemImage: "doc.text") }
                        }
                    }
                }

                if !document.recognizedText.isEmpty {
                    Section {
                        DisclosureGroup("Text found in it", isExpanded: $showText) {
                            Text(document.recognizedText).font(.caption).textSelection(.enabled)
                        }
                    }
                }

                Section {
                    if let shareURL {
                        ShareLink(item: shareURL) { Label("Share or save a copy", systemImage: "square.and.arrow.up") }
                    }
                    Button("Delete document", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Added \(document.createdAt.formatted(date: .long, time: .omitted))")
                }
            }
            .tint(color)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview($previewURL)
        .onAppear { shareURL = DocumentStore.shareableCopy(of: document) }
        .confirmationDialog("Delete \(document.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let fileName = document.storedFileName
                let doomed = document
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    DocumentStore.delete(fileName)
                    context.delete(doomed)
                }
            }
        } message: {
            Text("The file is removed from this iPhone and your backup.")
        }
    }
}
