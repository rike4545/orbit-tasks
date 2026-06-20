//
//  AttachmentTextIndexer.swift
//  Orbit Tasks
//  Sidecar attachment text indexing (OCR/PDF/Text) WITHOUT SwiftData schema changes.
//  Persists JSON in Documents/AttachmentTextIndex/<attachmentID>.json

import Foundation
import SwiftData
import UniformTypeIdentifiers
import _Concurrency

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Vision)
import Vision
#endif

#if canImport(PDFKit)
import PDFKit
#endif

enum AttachmentTextIndexer {

    // MARK: - Sidecar record

    struct Record: Codable {
        var indexedText: String?
        var indexedAt: Date?
    }

    // MARK: - Public API (Compatibility + Primary)

    /// Index by model (compat: allows modelContext parameter even though we don’t require it).
    @discardableResult
    static func indexIfNeeded(
        _ attachment: OrbitAttachment,
        modelContext: ModelContext? = nil,
        force: Bool = false
    ) async -> String? {
        await indexIfNeeded(
            attachmentID: attachment.id,
            relativePath: attachment.relativePath,
            utiString: attachment.uti,
            modelContext: modelContext,
            force: force
        )
    }

    /// Index by attachment identity + file info (compat: keeps modelContext param).
    @discardableResult
    static func indexIfNeeded(
        attachmentID: UUID,
        relativePath: String,
        utiString: String,
        modelContext: ModelContext? = nil,
        force: Bool = false
    ) async -> String? {
        let fileURL = AttachmentManager.fileURL(forRelativePath: relativePath)
        return await indexIfNeeded(
            attachmentID: attachmentID,
            fileURL: fileURL,
            utiString: utiString,
            force: force
        )
    }

    /// Force reindex convenience (older call sites often used `index(...)`).
    @discardableResult
    static func index(
        _ attachment: OrbitAttachment,
        modelContext: ModelContext? = nil
    ) async -> String? {
        await indexIfNeeded(attachment, modelContext: modelContext, force: true)
    }

    /// Detached helper (safe even if some files don’t import SwiftUI).
    static func indexIfNeededDetached(
        _ attachment: OrbitAttachment,
        modelContext: ModelContext? = nil,
        force: Bool = false
    ) {
        _Concurrency.Task(priority: .utility) {
            _ = await indexIfNeeded(attachment, modelContext: modelContext, force: force)
        }
    }

    /// Read indexed text.
    static func getIndexedText(for attachmentID: UUID) -> String? {
        loadRecord(for: attachmentID)?.indexedText
    }

    /// Read indexed timestamp.
    static func getIndexedAt(for attachmentID: UUID) -> Date? {
        loadRecord(for: attachmentID)?.indexedAt
    }

    /// Clear sidecar index.
    static func clearIndex(for attachmentID: UUID) {
        let url = recordURL(for: attachmentID)
        try? FileManager.default.removeItem(at: url)
    }

    /// Convenience clear.
    static func clearIndex(_ attachment: OrbitAttachment) {
        clearIndex(for: attachment.id)
    }

    /// Public extractor (so TaskEditorMode/SearchView/etc can call it directly if needed).
    static func extractText(
        fileURL: URL,
        utiString: String,
        maxPages: Int = 12,
        maxChars: Int = 80_000
    ) async -> String? {
        let type = UTType(utiString) ?? UTType(filenameExtension: fileURL.pathExtension) ?? .data

        if type.conforms(to: .pdf) {
            let pdf = extractPDFText(fileURL: fileURL, maxPages: maxPages)
            return clamp(pdf, maxChars: maxChars)
        }

        if type.conforms(to: .image) {
            #if canImport(UIKit) && canImport(Vision)
            let img = await extractImageText(fileURL: fileURL)
            return clamp(img, maxChars: maxChars)
            #else
            return nil
            #endif
        }

        if type.conforms(to: .text) || type.conforms(to: .plainText) {
            let txt = extractPlainText(fileURL: fileURL)
            return clamp(txt, maxChars: maxChars)
        }

        // Fallback: some things come in as public.data but are actually text
        let fallback = extractPlainText(fileURL: fileURL)
        return clamp(fallback, maxChars: maxChars)
    }

    // MARK: - Core indexing (private)

    @discardableResult
    private static func indexIfNeeded(
        attachmentID: UUID,
        fileURL: URL,
        utiString: String,
        force: Bool
    ) async -> String? {
        let existing = loadRecord(for: attachmentID)

        if !force,
           let at = existing?.indexedAt,
           let text = existing?.indexedText,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            _ = at
            return text
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            saveRecord(.init(indexedText: nil, indexedAt: nil), for: attachmentID)
            return nil
        }

        let text = await extractText(fileURL: fileURL, utiString: utiString)
        let cleaned = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText = (cleaned?.isEmpty == false) ? cleaned : nil

        saveRecord(.init(indexedText: finalText, indexedAt: Date()), for: attachmentID)
        return finalText
    }

    // MARK: - Sidecar IO

    private static func indexDirectoryURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("AttachmentTextIndex", isDirectory: true)
    }

    private static func ensureIndexDirectory() {
        let dir = indexDirectoryURL()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func recordURL(for id: UUID) -> URL {
        ensureIndexDirectory()
        return indexDirectoryURL().appendingPathComponent("\(id.uuidString).json")
    }

    private static func loadRecord(for id: UUID) -> Record? {
        let url = recordURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private static func saveRecord(_ record: Record, for id: UUID) {
        let url = recordURL(for: id)
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    // MARK: - Extractors

    private static func extractPlainText(fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return s?.nilIfEmpty
    }

    private static func extractPDFText(fileURL: URL, maxPages: Int) -> String? {
        #if canImport(PDFKit)
        guard let doc = PDFDocument(url: fileURL) else { return nil }

        // Prefer embedded selectable text
        if let embedded = doc.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !embedded.isEmpty {
            return embedded
        }

        // If you want OCR-on-PDF later, you can add it here (thumbnail OCR).
        // For now: embedded-only to keep it fast and reliable.
        _ = maxPages
        return nil
        #else
        _ = maxPages
        return nil
        #endif
    }

    #if canImport(UIKit) && canImport(Vision)
    private static func extractImageText(fileURL: URL) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                guard
                    let image = UIImage(contentsOfFile: fileURL.path),
                    let cg = image.cgImage
                else {
                    cont.resume(returning: nil)
                    return
                }

                let request = VNRecognizeTextRequest { req, _ in
                    let strings = (req.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .nilIfEmpty
                    cont.resume(returning: strings)
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: nil)
                }
            }
        }
    }
    #endif

    private static func clamp(_ s: String?, maxChars: Int) -> String? {
        guard let s, !s.isEmpty else { return nil }
        if s.count <= maxChars { return s }
        let idx = s.index(s.startIndex, offsetBy: maxChars)
        return String(s[..<idx])
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
