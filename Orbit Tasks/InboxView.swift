//
//  InboxView.swift
//  Orbit Tasks
//
//  Inbox = unscheduled + no project
//  Adds bottom Quick Add with NLP date parsing
//

import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    // Fetch open tasks only; filter in memory for reliability (avoids SwiftData predicate edge cases).
    @Query(
        filter: #Predicate<OrbitTask> { t in t.isCompleted == false },
        sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)]
    )
    private var openTasks: [OrbitTask]

    @State private var showAdd = false
    @State private var selection: Set<UUID> = []

    // Quick Add
    @State private var quickText: String = ""
    @State private var defaultToday: Bool = false
    @FocusState private var quickFocused: Bool

    private var inboxTasks: [OrbitTask] {
        openTasks
            .filter { $0.scheduledAt == nil && $0.project == nil && $0.listOverride != .someday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var overdueCount: Int {
        inboxTasks.filter { ($0.deadlineAt ?? .distantFuture) < Date() }.count
    }

    private var hasEditableTasks: Bool {
        !inboxTasks.isEmpty
    }

    var body: some View {
        List(selection: $selection) {
            OrbitFocusHeader(
                title: L10n.string("inbox.focus.title"),
                subtitle: L10n.string("inbox.focus.subtitle"),
                pills: [
                    OrbitStatPill(label: L10n.string("inbox.pill.items"), value: "\(inboxTasks.count)", systemImage: "tray.full"),
                    OrbitStatPill(label: L10n.string("inbox.pill.overdue"), value: "\(overdueCount)", systemImage: "flag"),
                    OrbitStatPill(label: L10n.string("inbox.pill.selected"), value: "\(selection.count)", systemImage: "checkmark.circle")
                ]
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if inboxTasks.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: L10n.string("inbox.empty.title"),
                    subtitle: L10n.string("inbox.empty.subtitle")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(inboxTasks) { task in
                        TaskRowView(task: task, onToggleDone: { toggleDone(task) }, onOpen: selection.isEmpty ? {
                            TaskEditorCoordinator.shared.present(task: task)
                        } : nil)
                            .tag(task.id)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { scheduleForToday(task) } label: {
                                    Label("Today", systemImage: "sun.max")
                                }
                                .tint(.blue)
                            }
                    }
                } header: {
                    HStack {
                        Text(L10n.string("inbox.section.title"))
                        Spacer()
                        Text("\(inboxTasks.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .orbitScreenChrome()
        .navigationTitle(L10n.string("nav.inbox"))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if hasEditableTasks {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Label(L10n.string("common.add"), systemImage: "plus")
                }
            }
        }
        .onChange(of: inboxTasks.count) { _, newCount in
            if newCount == 0 {
                selection.removeAll()
                editMode?.wrappedValue = .inactive
            }
        }
        .sheet(isPresented: $showAdd) {
            TaskEditorSheet(mode: .create(initialBucket: .inbox))
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if !selection.isEmpty {
                    TaskSelectionBar(
                        count: selection.count,
                        onComplete: { batchComplete() },
                        onScheduleToday: { batchScheduleToday() },
                        onMoveToEvening: { batchMoveEvening() },
                        onDelete: { batchDelete() }
                    )
                } else {
                    InboxQuickAddBar(
                        text: $quickText,
                        defaultToday: $defaultToday,
                        focused: $quickFocused,
                        onSubmit: { quickAddSubmit() }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .orbitBannerPlacement()
    }

    // MARK: - Single item actions

    private func toggleDone(_ task: OrbitTask) {
        task.isCompleted = true
        task.completedAt = Date()
        task.touch()
        try? modelContext.save()
        NotificationManager.shared.cancelReminder(for: task.id)
        TaskHaptics.success()
        OrbitInterstitialAdManager.shared.recordTaskCompletionEvent()
    }

    private func delete(_ task: OrbitTask) {
        NotificationManager.shared.cancelReminder(for: task.id)
        modelContext.delete(task)
        try? modelContext.save()
    }

    private func scheduleForToday(_ task: OrbitTask) {
        task.scheduledAt = Date()
        task.isEvening = false
        task.listOverride = .none
        task.touch()
        try? modelContext.save()
    }

    // MARK: - Quick Add

    private func quickAddSubmit() {
        let raw = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let lines = raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return }

        var created: [OrbitTask] = []

        for line in lines {
            let extraction = NaturalLanguageDateParser.extractDate(from: line)
            let cleaned = extraction.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = cleaned.isEmpty ? line : cleaned

            let scheduledAt: Date? = {
                if let d = extraction.date { return d }
                return defaultToday ? Date() : nil
            }()

            let isEvening = extraction.isEveningHint

            let task = OrbitTask(
                title: title,
                notes: "",
                project: nil,
                scheduledAt: scheduledAt,
                deadlineAt: nil,
                isEvening: isEvening
            )
            modelContext.insert(task)
            created.append(task)
        }

        try? modelContext.save()

        for t in created {
            scheduleReminderIfNeeded(for: t)
        }

        quickText = ""
        quickFocused = false
        TaskHaptics.success()
    }

    private func scheduleReminderIfNeeded(for task: OrbitTask) {
        guard let when = task.deadlineAt ?? task.scheduledAt else { return }
        guard when.timeIntervalSinceNow >= 60 else { return }

        Task {
            await NotificationManager.shared.scheduleReminder(
                for: task.id,
                title: task.title,
                at: when
            )
        }
    }

    // MARK: - Batch

    private func selectedInboxTasks() -> [OrbitTask] {
        inboxTasks.filter { selection.contains($0.id) }
    }

    private func batchComplete() {
        for t in selectedInboxTasks() {
            t.isCompleted = true
            t.completedAt = Date()
            t.touch()
            NotificationManager.shared.cancelReminder(for: t.id)
        }
        try? modelContext.save()
        selection.removeAll()
        TaskHaptics.success()
        OrbitInterstitialAdManager.shared.recordTaskCompletionEvent()
    }

    private func batchScheduleToday() {
        let now = Date()
        for t in selectedInboxTasks() {
            t.scheduledAt = now
            t.isEvening = false
            t.listOverride = .none
            t.touch()
        }
        try? modelContext.save()
        selection.removeAll()
    }

    private func batchMoveEvening() {
        let now = Date()
        for t in selectedInboxTasks() {
            t.scheduledAt = now
            t.isEvening = true
            t.listOverride = .none
            t.touch()
        }
        try? modelContext.save()
        selection.removeAll()
    }

    private func batchDelete() {
        for t in selectedInboxTasks() {
            NotificationManager.shared.cancelReminder(for: t.id)
            modelContext.delete(t)
        }
        try? modelContext.save()
        selection.removeAll()
    }
}

// MARK: - Inbox Quick Add Bar (file-private)

private struct InboxQuickAddBar: View {
    @Binding var text: String
    @Binding var defaultToday: Bool
    let focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                defaultToday.toggle()
            } label: {
                Image(systemName: defaultToday ? "sun.max" : "tray")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(defaultToday ? L10n.string("quickadd.default.today") : L10n.string("quickadd.default.inbox"))

            TextField(L10n.string("quickadd.placeholder"), text: $text, axis: .vertical)
                .lineLimit(1...3)
                .submitLabel(.done)
                .focused(focused)
                .onSubmit(onSubmit)

            Button(action: onSubmit) {
                Image(systemName: "arrow.up.circle.fill")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .orbitBarStyle()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused.wrappedValue = false }
            }
        }
    }
}
