//
//  AttachmentManager.swift
//  Orbit Tasks
//  AttachmentManager.swift
//  OrbitTasks
//

import Foundation
import UniformTypeIdentifiers

enum AttachmentManager {

    static func attachmentsDirectoryURL() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func saveData(_ data: Data, suggestedName: String, uti: UTType) throws -> (relativePath: String, displayName: String, utiString: String) {
        let dir = try attachmentsDirectoryURL()

        let ext = uti.preferredFilenameExtension ?? "dat"
        let filename = "\(UUID().uuidString).\(ext)"
        let fileURL = dir.appendingPathComponent(filename)

        try data.write(to: fileURL, options: [.atomic])

        let relativePath = "Attachments/\(filename)"
        let displayName = suggestedName.isEmpty ? filename : suggestedName
        return (relativePath, displayName, uti.identifier)
    }

    static func copyFile(from sourceURL: URL) throws -> (relativePath: String, displayName: String, utiString: String) {
        let dir = try attachmentsDirectoryURL()

        let ext = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destURL = dir.appendingPathComponent(filename)

        // Use security-scoped access if needed (fileImporter URLs can require it)
        let didStart = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStart { sourceURL.stopAccessingSecurityScopedResource() }
        }

        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let uti = UTType(filenameExtension: ext)?.identifier ?? UTType.data.identifier
        let relativePath = "Attachments/\(filename)"
        let displayName = sourceURL.lastPathComponent
        return (relativePath, displayName, uti)
    }

    nonisolated static func fileURL(forRelativePath rel: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent(rel)
    }
}
