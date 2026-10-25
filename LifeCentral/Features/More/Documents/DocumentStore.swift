import Foundation
import UIKit
import PDFKit
import Vision

/// Keeps document files in the app's private folder with iOS's strongest
/// file protection: they are encrypted and unreadable while the phone is locked.
enum DocumentStore {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Documents", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                     attributes: [.protectionKey: FileProtectionType.complete])
        }
        return url
    }

    static func url(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName)
    }

    /// Saves the bytes and returns the stored file name.
    static func save(_ data: Data, fileExtension: String) throws -> String {
        let name = "\(UUID().uuidString).\(fileExtension.lowercased())"
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtection])
        return name
    }

    static func data(for fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    static func delete(_ fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// A copy with a readable name, for sharing or opening in another app.
    static func shareableCopy(of document: Document) -> URL? {
        guard let data = data(for: document.storedFileName) else { return nil }
        let safe = document.title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe.isEmpty ? "Document" : safe).\(document.fileExtension)")
        try? data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Building files

    /// Several images (scanned pages or photos) as one PDF.
    static func pdf(from images: [UIImage]) -> Data? {
        let document = PDFDocument()
        for (index, image) in images.enumerated() {
            let sized = ImageTools.compressedJPEG(image).flatMap(UIImage.init(data:)) ?? image
            if let page = PDFPage(image: sized) { document.insert(page, at: index) }
        }
        return document.pageCount > 0 ? document.dataRepresentation() : nil
    }

    static func thumbnail(forPDF data: Data) -> Data? {
        guard let page = PDFDocument(data: data)?.page(at: 0) else { return nil }
        let image = page.thumbnail(of: CGSize(width: 300, height: 400), for: .mediaBox)
        return image.jpegData(compressionQuality: 0.7)
    }

    static func pageCount(ofPDF data: Data) -> Int {
        PDFDocument(data: data)?.pageCount ?? 1
    }

    static func text(ofPDF data: Data) -> String {
        PDFDocument(data: data)?.string ?? ""
    }

    /// Reads printed text from images so documents are searchable.
    static func recognizeText(in images: [UIImage]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var lines: [String] = []
                for image in images.prefix(10) {
                    guard let cgImage = image.cgImage else { continue }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    try? VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation).perform([request])
                    lines += (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }

    /// A guess at a title from the first lines of recognised text.
    static func suggestedTitle(from text: String) -> String? {
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let keywords = ["passport", "driving licence", "insurance", "policy", "certificate", "invoice", "receipt",
                        "boarding pass", "ticket", "contract", "statement", "prescription", "warranty", "booking"]
        for line in lines.prefix(15) {
            let lower = line.lowercased()
            if let word = keywords.first(where: { lower.contains($0) }) {
                return word.prefix(1).uppercased() + word.dropFirst()
            }
        }
        return lines.first { $0.count >= 4 && $0.count <= 40 }
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
