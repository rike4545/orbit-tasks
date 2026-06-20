//
//  TaskEditorMode.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/19/26.
//


//
//  TaskEditorMode.swift
//  Orbit Tasks
//
//  Local-only task editor (SwiftUI + SwiftData) + attachments + sidecar indexing.
//  Swift 6 • iOS 17+
//

import SwiftUI
import SwiftData
import PhotosUI
import QuickLook
import _Concurrency

// MARK: - Editor Routing

enum TaskEditorMode {
    case create(initialBucket: TaskEditorBucket)
    case edit(task: OrbitTask)
}

/// Don’t conform to Equatable (OrbitProject usually isn’t Equatable).
enum TaskEditorBucket {
    case inbox
    case today
    case plan
    case someday
    case scheduled(Date)
    case project(OrbitProject, heading: String?)
}

private struct ChecklistDraftItem: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var existingItem: OrbitChecklistItem?

    init(id: UUID = UUID(), title: String = "", isCompleted: Bool = false, existingItem: OrbitChecklistItem? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.existingItem = existingItem
    }
}

// MARK: - Task Editor Sheet

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: TaskEditorMode

    // Fields
    @State private var title: String = ""
    @State private var notes: String = ""

    @State private var scheduledAt: Date? = nil
    @State private var deadlineAt: Date? = nil
    @State private var isEvening: Bool = false

    @State private var priority: OrbitPriority = .none
    @State private var estimatedMinutes: Int? = nil
    @State private var energy: OrbitEnergy? = nil

    @State private var blockStartAt: Date? = nil
    @State private var blockDurationMinutes: Int? = nil
    @State private var showMoreDetails: Bool = false

    @State private var selectedProjectID: UUID? = nil
    @State private var projectHeading: String = ""
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var checklistItems: [ChecklistDraftItem] = []

    // Attachments
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showFileImporter: Bool = false
    @State private var indexingAttachmentIDs: Set<UUID> = []
    @State private var previewItem: AttachmentPreviewItem? = nil

    // Used to force the attachment list to refresh after sidecar index changes.
    @State private var indexRefreshToken: UUID = UUID()

    @Query(sort: [SortDescriptor(\OrbitProject.name, order: .forward)])
    private var allProjects: [OrbitProject]

    @Query(sort: [SortDescriptor(\OrbitTag.name, order: .forward)])
    private var allTags: [OrbitTag]

    @State private var editingTask: OrbitTask? = nil

    var body: some View {
        NavigationStack {
            Form {
                taskSection
                checklistSection
                planSection
                organizeSection
                moreSection
                attachmentsSection
                if modeIsEdit { deleteSection }
            }
            .navigationTitle(modeIsEdit ? "Edit Task" : "New Task")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .onAppear { loadIfNeeded() }
            .onChange(of: photoItem) { _, newValue in
                guard let item = newValue else { return }
                _Concurrency.Task { await handlePickedPhoto(item) }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                handleImportedFiles(result)
            }
            .sheet(item: $previewItem) { item in
                NavigationStack {
                    QuickLookPreview(url: item.url)
                        .navigationTitle(item.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { previewItem = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Derived

    private var modeIsEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        if editingTask != nil { return true }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Sections

    private var taskSection: some View {
        Section("Task") {
            TextField("Title", text: $title)
                .textInputAutocapitalization(.sentences)

            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...8)

            Button {
                let parsed = NaturalLanguageDateParser.extractDate(from: title)
                if let d = parsed.date {
                    title = parsed.cleanTitle
                    scheduledAt = d
                    if parsed.isEveningHint { isEvening = true }

                    if parsed.hadTime {
                        blockStartAt = d
                        if blockDurationMinutes == nil { blockDurationMinutes = 30 }
                        showMoreDetails = true
                    }
                }
            } label: {
                Label("Extract date from title", systemImage: "sparkles")
            }
        }
    }

    private var checklistSection: some View {
        Section {
            if checklistItems.isEmpty {
                Text("No steps yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach($checklistItems) { $item in
                    ChecklistDraftRow(item: $item)
                }
                .onDelete { offsets in
                    checklistItems.remove(atOffsets: offsets)
                }
            }

            Button {
                checklistItems.append(ChecklistDraftItem())
            } label: {
                Label("Add Step", systemImage: "plus.circle")
            }
        } header: {
            HStack {
                Text("Checklist")
                Spacer()
                if !checklistItems.isEmpty {
                    Text("\(checklistItems.filter(\.isCompleted).count)/\(checklistItems.count)")
                        .foregroundStyle(.secondary)
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private var planSection: some View {
        Section("Plan") {
            Toggle("This Evening", isOn: $isEvening)

            DateFieldRow(label: "Scheduled", date: $scheduledAt, systemImage: "calendar.badge.clock")
            DateFieldRow(label: "Deadline", date: $deadlineAt, systemImage: "flag")
        }
    }

    private var moreSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showMoreDetails) {
                DateFieldRow(label: "Block start", date: $blockStartAt, systemImage: "clock")

                HStack {
                    Label("Block minutes", systemImage: "hourglass")
                    Spacer()
                    TextField("e.g. 30", value: $blockDurationMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                Picker("Priority", selection: $priority) {
                    ForEach(OrbitPriority.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }

                HStack {
                    Label("Estimate (min)", systemImage: "timer")
                    Spacer()
                    TextField("e.g. 45", value: $estimatedMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }

                Picker("Energy", selection: Binding(
                    get: { energy },
                    set: { energy = $0 }
                )) {
                    Text("None").tag(OrbitEnergy?.none)
                    ForEach(OrbitEnergy.allCases, id: \.self) { e in
                        Text(e.label).tag(OrbitEnergy?.some(e))
                    }
                }
            } label: {
                Label("More", systemImage: "slider.horizontal.3")
            }
        }
    }

    private var organizeSection: some View {
        Section("Organize") {
            Picker("Project", selection: $selectedProjectID) {
                Text("None").tag(UUID?.none)
                ForEach(allProjects) { p in
                    Text(p.name).tag(UUID?.some(p.id))
                }
            }

            if selectedProjectID != nil {
                TextField("Heading", text: $projectHeading)
                    .textInputAutocapitalization(.words)
            }

            NavigationLink("Tags (\(selectedTagIDs.count))") {
                TagPickerView(allTags: allTags, selectedTagIDs: $selectedTagIDs)
            }
        }
    }

    private var attachmentsSection: some View {
        Section("Attachments") {
            if let task = editingTask {
                Group {
                    if task.attachments.isEmpty {
                        Text("No attachments yet.").foregroundStyle(.secondary)
                    } else {
                        // Refresh token forces redraw when sidecar updates.
                        ForEach(task.attachments, id: \.id) { att in
                            attachmentRow(att, in: task)
                                .id(indexRefreshToken.uuidString + att.id.uuidString)
                                .onAppear { indexAttachmentIfNeeded(att, in: task, force: false) }
                        }
                    }
                }

                if !task.attachments.isEmpty {
                    Button {
                        indexAllAttachments(in: task, force: false)
                    } label: {
                        Label("Index attachments for search", systemImage: "text.magnifyingglass")
                    }
                }
            } else {
                Text("Add an attachment to create a draft task (or tap Save first).")
                    .foregroundStyle(.secondary)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Add photo", systemImage: "photo")
            }

            Button { showFileImporter = true } label: {
                Label("Add file", systemImage: "doc")
            }
        }
    }

    private func attachmentRow(_ att: OrbitAttachment, in task: OrbitTask) -> some View {
        let isIndexing = indexingAttachmentIDs.contains(att.id)
        let currentIndexedText = AttachmentTextIndexer.getIndexedText(for: att.id)
        let currentIndexedAt = AttachmentTextIndexer.getIndexedAt(for: att.id)
        let isIndexed = (currentIndexedText?.isEmpty == false)

        return HStack(spacing: 10) {
            Image(systemName: "paperclip").foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(att.displayName).lineLimit(1)

                if isIndexing {
                    Text("Indexing for search…").font(.caption).foregroundStyle(.secondary)
                } else if isIndexed {
                    Text("Searchable").font(.caption).foregroundStyle(.secondary)
                } else if currentIndexedAt != nil {
                    Text("Not searchable").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Not indexed yet").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isIndexing {
                ProgressView()
            } else if isIndexed {
                Image(systemName: "text.magnifyingglass").foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            Button {
                let url = AttachmentManager.fileURL(forRelativePath: att.relativePath)
                previewItem = AttachmentPreviewItem(url: url, title: att.displayName)
            } label: {
                Color.clear
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button {
                indexAttachmentIfNeeded(att, in: task, force: true)
            } label: {
                Label(isIndexed ? "Reindex Text" : "Index Text", systemImage: "text.magnifyingglass")
            }

            Button(role: .destructive) {
                removeAttachment(att, from: task)
                AttachmentTextIndexer.clearIndex(for: att.id)
                indexRefreshToken = UUID()
            } label: {
                Label("Remove Attachment", systemImage: "trash")
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                deleteTask()
            } label: {
                Label("Delete Task", systemImage: "trash")
            }
        }
    }

    // MARK: - Load / Cancel

    private func loadIfNeeded() {
        switch mode {
        case .edit(let task):
            editingTask = task

            title = task.title
            notes = task.notes

            scheduledAt = task.scheduledAt
            deadlineAt = task.deadlineAt
            isEvening = task.isEvening

            priority = task.priority
            estimatedMinutes = task.estimatedMinutes
            energy = task.energy

            blockStartAt = task.blockStartAt
            blockDurationMinutes = task.blockDurationMinutes
            showMoreDetails = hasMoreDetails(task)

            selectedProjectID = task.project?.id
            projectHeading = task.projectHeading ?? ""
            selectedTagIDs = Set(task.tags.map(\.id))
            checklistItems = task.sortedChecklistItems.map {
                ChecklistDraftItem(
                    id: $0.id,
                    title: $0.title,
                    isCompleted: $0.isCompleted,
                    existingItem: $0
                )
            }

            indexAllAttachments(in: task, force: false)

        case .create(let bucket):
            switch bucket {
            case .today:
                scheduledAt = Date()
                isEvening = false
            case .scheduled(let date):
                scheduledAt = date
                isEvening = false
            case .someday:
                scheduledAt = nil
                isEvening = false
            case .project(let project, let heading):
                selectedProjectID = project.id
                projectHeading = heading ?? ""
            case .plan, .inbox:
                break
            }
        }
    }

    private func hasMoreDetails(_ task: OrbitTask) -> Bool {
        task.blockStartAt != nil ||
        task.blockDurationMinutes != nil ||
        task.priority != .none ||
        task.estimatedMinutes != nil ||
        task.energy != nil
    }

    private func cancel() {
        if case .create = mode, let t = editingTask, shouldDeleteDraftOnCancel(t) {
            modelContext.delete(t)
            try? modelContext.save()
        }
        dismiss()
    }

    private func shouldDeleteDraftOnCancel(_ task: OrbitTask) -> Bool {
        let hasAnyMeaningfulData =
            !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            task.scheduledAt != nil ||
            task.deadlineAt != nil ||
            task.project != nil ||
            !task.tags.isEmpty ||
            !task.attachments.isEmpty ||
            !task.checklistItems.isEmpty

        return !hasAnyMeaningfulData
    }

    // MARK: - Draft support

    @MainActor
    private func ensureDraftTaskExists(suggestedTitle: String? = nil) -> OrbitTask? {
        if let t = editingTask { return t }

        let selectedProject = allProjects.first(where: { $0.id == selectedProjectID })
        let selectedTags = allTags.filter { selectedTagIDs.contains($0.id) }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = trimmed.isEmpty ? (suggestedTitle ?? "New Task") : trimmed

        let bucket: TaskEditorBucket = {
            if case .create(let b) = mode { return b }
            return .inbox
        }()

        let newTask = OrbitTask(
            title: baseTitle,
            notes: notes,
            project: selectedProject,
            projectHeading: normalizedProjectHeading(for: selectedProject),
            scheduledAt: scheduledAtForBucket(bucket),
            deadlineAt: deadlineAt,
            isEvening: isEvening,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            energy: energy,
            blockStartAt: blockStartAt,
            blockDurationMinutes: blockDurationMinutes
        )
        if case .someday = bucket {
            newTask.listOverride = .someday
        }

        newTask.tags.append(contentsOf: selectedTags)
        syncChecklistItems(on: newTask)

        modelContext.insert(newTask)
        editingTask = newTask
        try? modelContext.save()

        return newTask
    }

    // MARK: - Save/Delete

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let selectedProject = allProjects.first(where: { $0.id == selectedProjectID })
        let selectedTags = allTags.filter { selectedTagIDs.contains($0.id) }

        switch mode {
        case .edit(let task):
            applyFields(to: task, titleOverride: trimmedTitle.isEmpty ? task.title : trimmedTitle, project: selectedProject, tags: selectedTags)
            syncChecklistItems(on: task)
            scheduleNotificationIfNeeded(task)

        case .create(let bucket):
            if let draft = editingTask {
                let resolvedTitle = trimmedTitle.isEmpty ? draft.title : trimmedTitle
                applyFields(to: draft, titleOverride: resolvedTitle, project: selectedProject, tags: selectedTags)
                if draft.scheduledAt == nil { draft.scheduledAt = scheduledAtForBucket(bucket) }
                if case .someday = bucket {
                    draft.listOverride = .someday
                }
                syncChecklistItems(on: draft)
                scheduleNotificationIfNeeded(draft)
            } else {
                let resolvedTitle = trimmedTitle.isEmpty ? "New Task" : trimmedTitle

                let newTask = OrbitTask(
                    title: resolvedTitle,
                    notes: notes,
                    project: selectedProject,
                    projectHeading: normalizedProjectHeading(for: selectedProject),
                    scheduledAt: scheduledAtForBucket(bucket),
                    deadlineAt: deadlineAt,
                    isEvening: isEvening,
                    priority: priority,
                    estimatedMinutes: estimatedMinutes,
                    energy: energy,
                    blockStartAt: blockStartAt,
                    blockDurationMinutes: blockDurationMinutes
                )

                if case .someday = bucket {
                    newTask.listOverride = .someday
                }

                newTask.tags.append(contentsOf: selectedTags)
                syncChecklistItems(on: newTask)

                modelContext.insert(newTask)
                editingTask = newTask
                scheduleNotificationIfNeeded(newTask)
            }
        }

        try? modelContext.save()
        TaskHaptics.success()
        dismiss()
    }

    private func applyFields(to task: OrbitTask, titleOverride: String, project: OrbitProject?, tags: [OrbitTag]) {
        task.title = titleOverride
        task.notes = notes

        task.scheduledAt = scheduledAt
        task.deadlineAt = deadlineAt
        task.isEvening = isEvening
        if scheduledAt != nil {
            task.listOverride = .none
        }

        task.priority = priority
        task.estimatedMinutes = estimatedMinutes
        task.energy = energy

        task.blockStartAt = blockStartAt
        task.blockDurationMinutes = blockDurationMinutes

        task.project = project
        task.projectHeading = normalizedProjectHeading(for: project)

        task.tags.removeAll()
        task.tags.append(contentsOf: tags)

        task.touch()
    }

    private func syncChecklistItems(on task: OrbitTask) {
        let normalized = checklistItems
            .map { item in
                ChecklistDraftItem(
                    id: item.id,
                    title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    isCompleted: item.isCompleted,
                    existingItem: item.existingItem
                )
            }
            .filter { !$0.title.isEmpty }

        let retainedIDs = Set(normalized.compactMap { $0.existingItem?.id })
        let removedItems = task.checklistItems.filter { !retainedIDs.contains($0.id) }
        for item in removedItems {
            task.checklistItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
        }

        for (index, draft) in normalized.enumerated() {
            if let existing = draft.existingItem {
                existing.title = draft.title
                existing.isCompleted = draft.isCompleted
                existing.sortOrder = index
                existing.touch()
            } else {
                let item = OrbitChecklistItem(
                    title: draft.title,
                    isCompleted: draft.isCompleted,
                    sortOrder: index,
                    task: task
                )
                task.checklistItems.append(item)
            }
        }

        checklistItems = normalized.enumerated().map { index, draft in
            if let existing = draft.existingItem {
                return ChecklistDraftItem(
                    id: existing.id,
                    title: existing.title,
                    isCompleted: existing.isCompleted,
                    existingItem: existing
                )
            }

            let created = task.sortedChecklistItems.first { $0.sortOrder == index && $0.title == draft.title }
            return ChecklistDraftItem(
                id: created?.id ?? draft.id,
                title: draft.title,
                isCompleted: draft.isCompleted,
                existingItem: created
            )
        }

        task.touch()
    }

    private func normalizedProjectHeading(for project: OrbitProject?) -> String? {
        guard project != nil else { return nil }
        let trimmed = projectHeading.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func scheduledAtForBucket(_ bucket: TaskEditorBucket) -> Date? {
        switch bucket {
        case .today: return scheduledAt ?? Date()
        case .inbox: return nil
        case .someday: return nil
        case .scheduled(let date): return scheduledAt ?? date
        case .plan: return scheduledAt
        case .project: return scheduledAt
        }
    }

    private func deleteTask() {
        guard case .edit(let task) = mode else { return }
        NotificationManager.shared.cancelReminder(for: task.id)
        modelContext.delete(task)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Notifications

    private func scheduleNotificationIfNeeded(_ task: OrbitTask) {
        _Concurrency.Task {
            if let when = task.deadlineAt ?? task.scheduledAt {
                await NotificationManager.shared.scheduleReminder(for: task.id, title: task.title, at: when)
            } else {
                NotificationManager.shared.cancelReminder(for: task.id)
            }
        }
    }

    // MARK: - Attachments (import + remove + indexing)

    private func removeAttachment(_ att: OrbitAttachment, from task: OrbitTask) {
        task.attachments.removeAll { $0.id == att.id }
        task.touch()
        try? modelContext.save()
        indexRefreshToken = UUID()
    }

    @MainActor
    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let task = ensureDraftTaskExists(suggestedTitle: "Photo")
        guard let task else { return }
        addPhotoData(data, to: task)
    }

    private func handleImportedFiles(_ result: Result<[URL], Error>) {
        let urls: [URL]
        switch result {
        case .success(let u): urls = u
        case .failure: return
        }

        let suggested = urls.first?.lastPathComponent
        let task = ensureDraftTaskExists(suggestedTitle: suggested)
        guard let task else { return }

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let saved = try AttachmentManager.copyFile(from: url)
                let att = OrbitAttachment(
                    displayName: saved.displayName,
                    relativePath: saved.relativePath,
                    uti: saved.utiString,
                    task: task
                )

                task.attachments.append(att)
                task.touch()
                try? modelContext.save()
                indexAttachmentIfNeeded(att, in: task, force: false)
            } catch {
                // ignore per-file failures
            }
        }
    }

    @MainActor
    private func addPhotoData(_ data: Data, to task: OrbitTask) {
        do {
            let saved = try AttachmentManager.saveData(data, suggestedName: "Photo", uti: .image)

            let att = OrbitAttachment(
                displayName: saved.displayName,
                relativePath: saved.relativePath,
                uti: saved.utiString,
                task: task
            )

            task.attachments.append(att)
            task.touch()
            try? modelContext.save()
            indexAttachmentIfNeeded(att, in: task, force: false)
        } catch {
            // ignore
        }
    }

    private func indexAllAttachments(in task: OrbitTask, force: Bool) {
        for att in task.attachments {
            indexAttachmentIfNeeded(att, in: task, force: force)
        }
    }

    private func indexAttachmentIfNeeded(_ att: OrbitAttachment, in task: OrbitTask, force: Bool) {
        // If already indexed and not forcing, skip.
        if !force, let t = AttachmentTextIndexer.getIndexedText(for: att.id), !t.isEmpty { return }
        if indexingAttachmentIDs.contains(att.id) { return }

        let attID = att.id
        let rel = att.relativePath
        let uti = att.uti

        indexingAttachmentIDs.insert(attID)

        _Concurrency.Task(priority: .utility) {
            _ = await AttachmentTextIndexer.indexIfNeeded(
                attachmentID: attID,
                relativePath: rel,
                utiString: uti,
                modelContext: modelContext,
                force: force
            )

            await MainActor.run {
                indexingAttachmentIDs.remove(attID)
                task.touch()
                try? modelContext.save()
                indexRefreshToken = UUID()
            }
        }
    }
}

// MARK: - Checklist Row

private struct ChecklistDraftRow: View {
    @Binding var item: ChecklistDraftItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                item.isCompleted.toggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "Mark step incomplete" : "Mark step complete")

            TextField("Step", text: $item.title)
                .textInputAutocapitalization(.sentences)
                .strikethrough(item.isCompleted, color: .secondary)
        }
    }
}

// MARK: - Date Field Row

struct DateFieldRow: View {
    let label: String
    @Binding var date: Date?
    let systemImage: String

    @State private var tempDate: Date = Date()
    @State private var showPicker: Bool = false

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            if let d = date {
                Text(DateHelpers.compactDateTimeString(d)).foregroundStyle(.secondary)
            } else {
                Text("None").foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .overlay {
            Button {
                tempDate = date ?? Date()
                showPicker = true
            } label: {
                Color.clear
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                Form {
                    DatePicker("Select", selection: $tempDate)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle(label)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear") { date = nil; showPicker = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { date = tempDate; showPicker = false }
                    }
                }
            }
        }
    }
}

// MARK: - Tag Picker (IDs)

struct TagPickerView: View {
    let allTags: [OrbitTag]
    @Binding var selectedTagIDs: Set<UUID>

    var body: some View {
        List {
            ForEach(allTags) { tag in
                Button {
                    if selectedTagIDs.contains(tag.id) { selectedTagIDs.remove(tag.id) }
                    else { selectedTagIDs.insert(tag.id) }
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        if selectedTagIDs.contains(tag.id) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Tags")
    }
}

// MARK: - Attachment Preview

private struct AttachmentPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
