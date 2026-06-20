//
//  SettingsView.swift
//  Orbit Tasks
//
//  Attachment indexing (OCR/PDF text) lives here so Option B (“reference-rich”)
//  becomes real: search can match inside attachments.
//  Swift 6 • iOS 17+ • SwiftData
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Vision
import PDFKit
import UIKit
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var purchases: OrbitPurchaseManager
    @Environment(\.modelContext) private var modelContext

    // Attachments are the unit of indexing.
    @Query(sort: [SortDescriptor(\OrbitAttachment.createdAt, order: .reverse)])
    private var attachments: [OrbitAttachment]

    @State private var isIndexing: Bool = false
    @State private var indexProgressDone: Int = 0
    @State private var indexProgressTotal: Int = 0
    @State private var lastIndexMessage: String? = nil
    @State private var indexingTask: Task<Void, Never>? = nil
    #if DEBUG
    @State private var adDebugStatus: String? = nil
    #endif

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Picker("Theme", selection: $settings.palette) {
                    ForEach(AppSettings.Palette.allCases) { p in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(HexColor.color(p.accentHex) ?? .accentColor)
                                .frame(width: 12, height: 12)
                            Text(p.label)
                        }
                        .tag(p)
                    }
                }

                Toggle("Themed background", isOn: $settings.themedBackground)
                Toggle("Custom accent", isOn: $settings.useCustomAccent)

                if settings.useCustomAccent {
                    ColorPicker("Accent color", selection: Binding(
                        get: { settings.accentColor },
                        set: { newColor in
                            if let hex = HexColor.hexString(from: newColor) {
                                settings.customAccentHex = hex
                            }
                        }
                    ), supportsOpacity: false)

                    HStack {
                        Text("Hex")
                        Spacer()
                        TextField("#RRGGBB", text: $settings.customAccentHex)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: 160)
                    }
                } else {
                    HStack {
                        Text("Accent preview")
                        Spacer()
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(settings.accentColor)
                            .frame(width: 44, height: 26)
                    }
                }
            }

            Section("Text") {
                Picker("Text size", selection: $settings.textSize) {
                    ForEach(AppSettings.TextSize.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }

                Text("Applies across the app using Dynamic Type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
                Toggle("24-hour time", isOn: $settings.use24HourTime)
            }

            Section(L10n.string("settings.remove_ads.title")) {
                if purchases.hasRemovedAds {
                    Label(L10n.string("settings.remove_ads.active"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        Task { await purchases.purchaseRemoveAds() }
                    } label: {
                        Label("\(L10n.string("settings.remove_ads.button")) (\(purchases.removeAdsPriceText))", systemImage: "cart.badge.plus")
                    }
                    .disabled(purchases.isPurchasing || purchases.isLoadingProducts)

                    Text(L10n.string("settings.remove_ads.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(L10n.string("settings.restore_purchases")) {
                    Task { await purchases.restorePurchases() }
                }
                .disabled(purchases.isPurchasing)

                if let status = purchases.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            #if DEBUG
            Section("AdMob Testing") {
                Toggle(
                    "Use Google test ad units",
                    isOn: Binding(
                        get: { OrbitAds.isUsingTestAds },
                        set: { enabled in
                            OrbitAds.setUseTestAds(enabled)
                            adDebugStatus = "Ad mode changed to \(enabled ? "test" : "production")."
                        }
                    )
                )

                Toggle(
                    "Disable interstitials",
                    isOn: Binding(
                        get: { OrbitAds.disableInterstitialsForDebug },
                        set: { disabled in
                            OrbitAds.setDisableInterstitialsForDebug(disabled)
                            adDebugStatus = disabled ? "Interstitials disabled." : "Interstitials enabled."
                        }
                    )
                )

                Toggle(
                    "Disable app open ads",
                    isOn: Binding(
                        get: { OrbitAds.disableAppOpenAdsForDebug },
                        set: { disabled in
                            OrbitAds.setDisableAppOpenAdsForDebug(disabled)
                            adDebugStatus = disabled ? "App open ads disabled." : "App open ads enabled."
                        }
                    )
                )

                HStack {
                    Text("Banner Unit")
                    Spacer()
                    Text(OrbitAds.bannerAdUnitID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Interstitial Unit")
                    Spacer()
                    Text(OrbitAds.interstitialAdUnitID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("App Open Unit")
                    Spacer()
                    Text(OrbitAds.appOpenAdUnitID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Button("Preload interstitial") {
                    adDebugStatus = OrbitAds.preloadInterstitialForDebug()
                }

                Button("Show interstitial now") {
                    adDebugStatus = OrbitAds.presentInterstitialForDebug()
                }

                Button("Preload app open") {
                    adDebugStatus = OrbitAds.preloadAppOpenForDebug()
                }

                Button("Show app open now") {
                    adDebugStatus = OrbitAds.presentAppOpenForDebug()
                }

                Button("Open Ad Inspector") {
                    Task { adDebugStatus = await OrbitAds.openAdInspectorForDebug() }
                }

                if let adDebugStatus {
                    Text(adDebugStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Debug-only controls. Keep test units enabled while developing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            // ✅ Option B: Make attachments searchable
            Section("Search & Indexing") {
                let indexedCount = attachments.filter { ($0.ocrText?.isEmpty == false) }.count

                HStack {
                    Text("Attachments")
                    Spacer()
                    Text("\(attachments.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Searchable")
                    Spacer()
                    Text("\(indexedCount)")
                        .foregroundStyle(.secondary)
                }

                if isIndexing {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Indexing attachments…")
                            Text("\(indexProgressDone) / \(indexProgressTotal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Cancel", role: .cancel) {
                            cancelIndexing()
                        }
                    }

                    if let msg = lastIndexMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        startIndexing(force: false)
                    } label: {
                        Label("Index attachments now", systemImage: "text.magnifyingglass")
                    }
                    .disabled(attachments.isEmpty)

                    Button {
                        startIndexing(force: true)
                    } label: {
                        Label("Reindex all attachments", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(attachments.isEmpty)

                    Button(role: .destructive) {
                        clearAttachmentIndex()
                    } label: {
                        Label("Clear attachment index", systemImage: "eraser")
                    }
                    .disabled(attachments.isEmpty)
                }

                Text("Indexing runs on-device (OCR for images, text extraction for text PDFs) so Search can match inside attachments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    settings.resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            }

            Section("About") {
                HStack {
                    Text("App")
                    Spacer()
                    Text("Orbit Tasks")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(L10n.string("nav.settings"))
        .task {
            await purchases.refreshEntitlements()
            await purchases.loadProducts()
        }
        .onDisappear {
            // Avoid runaway work if user navigates away.
            if isIndexing { cancelIndexing() }
        }
        .orbitBannerPlacement()
    }

    // MARK: - Indexing Controls

    @MainActor
    private func startIndexing(force: Bool) {
        cancelIndexing()

        // Choose what to index.
        let targets: [OrbitAttachment] = attachments.filter { att in
            if force { return true }
            // Only index if missing / empty
            return (att.ocrText?.isEmpty ?? true)
        }

        isIndexing = true
        indexProgressDone = 0
        indexProgressTotal = targets.count
        lastIndexMessage = targets.isEmpty ? "Everything is already indexed." : nil

        guard !targets.isEmpty else {
            isIndexing = false
            return
        }

        indexingTask = Task {
            var touched = 0

            for att in targets {
                if Task.isCancelled { break }

                // Extract off-main for responsiveness.
                let (rel, uti, name) = (att.relativePath, att.uti, att.displayName)
                let fileURL = AttachmentManager.fileURL(forRelativePath: rel)

                let extracted: String? = await Task.detached(priority: .utility) {
                    return await AttachmentTextExtractor.extractText(fileURL: fileURL, utiString: uti)
                }.value

                await MainActor.run {
                    // Store results
                    att.ocrText = (extracted?.isEmpty == false) ? extracted : nil
                    att.ocrIndexedAt = Date()

                    indexProgressDone += 1
                    lastIndexMessage = "Indexed: \(name)"
                }

                touched += 1
                if touched % 10 == 0 {
                    await MainActor.run { try? modelContext.save() }
                }
            }

            await MainActor.run {
                try? modelContext.save()
                isIndexing = false
                indexingTask = nil
            }
        }
    }

    @MainActor
    private func cancelIndexing() {
        indexingTask?.cancel()
        indexingTask = nil
        isIndexing = false
    }

    @MainActor
    private func clearAttachmentIndex() {
        cancelIndexing()
        for att in attachments {
            att.ocrText = nil
            att.ocrIndexedAt = nil
        }
        try? modelContext.save()
        lastIndexMessage = "Cleared index."
    }
}

// MARK: - OCR / Text Extraction

private enum AttachmentTextExtractor {

    static func extractText(fileURL: URL, utiString: String) async -> String? {
        let type = UTType(utiString) ?? UTType(filenameExtension: fileURL.pathExtension)

        if type?.conforms(to: .pdf) == true {
            // Best effort: extract selectable text from PDF.
            return clamp(extractPDFText(fileURL: fileURL))
        }

        if type?.conforms(to: .image) == true {
            return clamp(await extractImageText(fileURL: fileURL))
        }

        if type?.conforms(to: .text) == true {
            return clamp(extractPlainText(fileURL: fileURL))
        }

        return nil
    }

    private static func extractPDFText(fileURL: URL) -> String? {
        guard let doc = PDFDocument(url: fileURL) else { return nil }
        let s = doc.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    private static func extractPlainText(fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    private static func extractImageText(fileURL: URL) async -> String? {
        guard let image = UIImage(contentsOfFile: fileURL.path),
              let cg = image.cgImage else { return nil }

        return await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                cont.resume(returning: (text?.isEmpty == false) ? text : nil)
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([req])
            } catch {
                cont.resume(returning: nil)
            }
        }
    }

    private static func clamp(_ s: String?, maxChars: Int = 80_000) -> String? {
        guard let s, !s.isEmpty else { return nil }
        if s.count <= maxChars { return s }
        let idx = s.index(s.startIndex, offsetBy: maxChars)
        return String(s[..<idx])
    }
}
