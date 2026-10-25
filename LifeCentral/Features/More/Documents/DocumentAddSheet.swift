import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

/// Add a document by scanning it, picking a file or choosing photos.
/// Opened from Documents, the + button, a bill, a trip or a plan item.
struct DocumentAddSheet: View {
    var presetFolder: String?
    var trip: Trip?
    var bill: Bill?
    var tripItem: TripItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var documents: [Document]

    @State private var showScanner = false
    @State private var showImporter = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pending: PendingFile?
    @State private var isWorking = false
    @State private var errorText: String?

    @State private var title = ""
    @State private var folder = "Other"
    @State private var hasExpiry = false
    @State private var expiresAt = Date.now.adding(months: 12)
    @State private var remindMonths = 3
    @State private var notes = ""

    struct PendingFile {
        var data: Data
        var fileExtension: String
        var originalName: String
        var source: DocumentSource
        var pageCount: Int
        var thumbnail: Data?
        var text: String
    }

    private let color = Area.documents.color

    private var folders: [String] {
        var list = DocumentFolder.defaults
        for name in documents.map(\.folder) where !list.contains(name) { list.append(name) }
        return list
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pending {
                    details(pending)
                } else {
                    chooser
                }
            }
            .navigationTitle(pending == nil ? "Add document" : "Save document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if pending != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                            .fontWeight(.bold)
                    }
                }
            }
            .tint(color)
        }
        .onAppear {
            folder = presetFolder ?? (trip != nil || tripItem != nil ? "Travel" : "Other")
            remindMonths = UserDefaults.standard.object(forKey: SettingsKey.documentReminderMonths) as? Int ?? 3
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { images in
                showScanner = false
                Task { await useImages(images, source: .scan) }
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .image, .plainText, .item]) { result in
            if case .success(let url) = result { Task { await useFile(url) } }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await usePhotos(items) }
        }
    }

    // MARK: Step 1

    private var chooser: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let link = linkText {
                    Label(link, systemImage: "link").font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if VNDocumentCameraViewController.isSupported {
                    sourceButton("Scan with the camera", detail: "Straightens pages and reads the text", symbol: "doc.viewfinder") {
                        showScanner = true
                    }
                }
                sourceButton("Choose a file", detail: "PDF, image or any file from Files, iCloud Drive or email", symbol: "folder") {
                    showImporter = true
                }
                PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                    sourceRow("Choose photos", detail: "Several photos become one PDF", symbol: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                if isWorking {
                    ProgressView("Reading the document…").padding(.top, 12)
                }
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red)
                }
                Label("Documents are stored encrypted on this iPhone and included in your encrypted iCloud backup.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .disabled(isWorking)
    }

    private var linkText: String? {
        if let tripItem { return "Will be attached to \(tripItem.title)" }
        if let trip { return "Will be attached to \(trip.name)" }
        if let bill { return "Will be attached to \(bill.name)" }
        return nil
    }

    private func sourceButton(_ title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { sourceRow(title, detail: detail, symbol: symbol) }
            .buttonStyle(.plain)
    }

    private func sourceRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            IconChip(symbol: symbol, color: color, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .card()
    }

    // MARK: Step 2

    private func details(_ file: PendingFile) -> some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    if let thumb = file.thumbnail, let image = UIImage(data: thumb) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(width: 70, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        IconChip(symbol: "doc.text", color: color, size: 70)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.fileExtension.uppercased()).font(.caption.weight(.bold)).foregroundStyle(color)
                        Text("\(file.pageCount) page\(file.pageCount == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Choose another") { pending = nil }.font(.footnote)
                    }
                }
                TextField("Title, e.g. Passport", text: $title)
            }

            Section("Folder") {
                FlowLayout {
                    ForEach(folders, id: \.self) { item in
                        ChoiceChip(title: item, isOn: folder == item, color: color) { folder = item }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Has an expiry date", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("Expires", selection: $expiresAt, displayedComponents: .date)
                    Stepper("Remind me \(remindMonths) month\(remindMonths == 1 ? "" : "s") before", value: $remindMonths, in: 1...12)
                }
                TextField("Notes, e.g. policy number", text: $notes, axis: .vertical)
            } footer: {
                if hasExpiry { Text("You'll get a reminder in time to renew it.") }
            }

            if !file.text.isEmpty {
                Section("Text found in it") {
                    Text(file.text.prefix(400) + (file.text.count > 400 ? "…" : ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Reading the input

    @MainActor
    private func useImages(_ images: [UIImage], source: DocumentSource) async {
        guard !images.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        let text = await DocumentStore.recognizeText(in: images)
        let file: PendingFile
        if images.count == 1, source == .photo, let jpeg = ImageTools.compressedJPEG(images[0], maxSide: 2400, quality: 0.8) {
            file = PendingFile(data: jpeg, fileExtension: "jpg", originalName: "Photo.jpg", source: source, pageCount: 1,
                               thumbnail: ImageTools.thumbnail(images[0]), text: text)
        } else if let pdf = DocumentStore.pdf(from: images) {
            file = PendingFile(data: pdf, fileExtension: "pdf", originalName: "Scan.pdf", source: source, pageCount: images.count,
                               thumbnail: ImageTools.thumbnail(images[0]), text: text)
        } else {
            errorText = "Couldn't read those pages. Try again."
            return
        }
        present(file, suggested: DocumentStore.suggestedTitle(from: text))
    }

    @MainActor
    private func usePhotos(_ items: [PhotosPickerItem]) async {
        isWorking = true
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        photoItems = []
        isWorking = false
        await useImages(images, source: .photo)
    }

    @MainActor
    private func useFile(_ url: URL) async {
        isWorking = true
        defer { isWorking = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorText = "Couldn't open that file."
            return
        }
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
        let name = url.deletingPathExtension().lastPathComponent
        var file = PendingFile(data: data, fileExtension: ext, originalName: url.lastPathComponent, source: .file,
                               pageCount: 1, thumbnail: nil, text: "")
        if ext == "pdf" {
            file.pageCount = DocumentStore.pageCount(ofPDF: data)
            file.thumbnail = DocumentStore.thumbnail(forPDF: data)
            file.text = DocumentStore.text(ofPDF: data)
            if file.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let page = UIImage(data: file.thumbnail ?? Data()) {
                file.text = await DocumentStore.recognizeText(in: [page])
            }
        } else if let image = UIImage(data: data) {
            file.thumbnail = ImageTools.thumbnail(image)
            file.text = await DocumentStore.recognizeText(in: [image])
        }
        present(file, suggested: name)
    }

    private func present(_ file: PendingFile, suggested: String?) {
        errorText = nil
        if title.isEmpty { title = suggested ?? "" }
        pending = file
    }

    private func save() {
        guard let file = pending else { return }
        do {
            let stored = try DocumentStore.save(file.data, fileExtension: file.fileExtension)
            let document = Document(title: title.trimmingCharacters(in: .whitespaces), folder: folder, storedFileName: stored,
                                    fileExtension: file.fileExtension, source: file.source)
            context.insert(document)
            document.originalFileName = file.originalName
            document.pageCount = file.pageCount
            document.thumbnail = file.thumbnail
            document.recognizedText = file.text
            document.notes = notes
            document.expiresAt = hasExpiry ? expiresAt.startOfDay : nil
            document.remindDaysBefore = remindMonths * 30
            document.trip = trip ?? tripItem?.trip
            document.tripItem = tripItem
            document.bill = bill
            dismiss()
        } catch {
            errorText = "Couldn't save the document: \(error.localizedDescription)"
            pending = nil
        }
    }
}

/// Apple's document scanner: finds page edges, straightens and cleans them up.
struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
