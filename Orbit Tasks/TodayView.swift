//
//  TodayView.swift
//  Orbit Tasks
//
//  Today = scheduled today, split into Today vs This Evening
//  Adds bottom Quick Add with NLP date parsing
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @Query(
        filter: #Predicate<OrbitTask> { t in t.isCompleted == false },
        sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)]
    )
    private var openTasks: [OrbitTask]

    @State private var showAdd = false
    @State private var selection: Set<UUID> = []

    // Quick Add
    @State private var quickText: String = ""
    @State private var defaultEvening: Bool = false
    @FocusState private var quickFocused: Bool

    private var todayTasks: [OrbitTask] {
        let items = openTasks.compactMap { t -> OrbitTask? in
            guard let s = t.scheduledAt, Calendar.current.isDateInToday(s) else { return nil }
            return t
        }

        // Sort: daytime first, then by time, then by createdAt
        return items.sorted { a, b in
            if a.isEvening != b.isEvening { return a.isEvening == false }
            let at = a.scheduledAt ?? .distantFuture
            let bt = b.scheduledAt ?? .distantFuture
            if at != bt { return at < bt }
            return a.createdAt < b.createdAt
        }
    }

    private var overdueTasks: [OrbitTask] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)

        return openTasks
            .filter { task in
                if let scheduledAt = task.scheduledAt, scheduledAt < startOfToday {
                    return true
                }

                if let deadlineAt = task.deadlineAt,
                   deadlineAt < now,
                   task.scheduledAt.map({ Calendar.current.isDateInToday($0) }) != true {
                    return true
                }

                return false
            }
            .sorted {
                let a = $0.deadlineAt ?? $0.scheduledAt ?? .distantFuture
                let b = $1.deadlineAt ?? $1.scheduledAt ?? .distantFuture
                if a != b { return a < b }
                return $0.createdAt < $1.createdAt
            }
    }

    private var daytime: [OrbitTask] { todayTasks.filter { !$0.isEvening } }
    private var evening: [OrbitTask] { todayTasks.filter { $0.isEvening } }
    private var visibleTasks: [OrbitTask] { overdueTasks + daytime + evening }
    private var overdueCount: Int { overdueTasks.count }

    private var hasEditableTasks: Bool {
        !visibleTasks.isEmpty
    }

    var body: some View {
        List(selection: $selection) {
            OrbitFocusHeader(
                title: L10n.string("today.focus.title"),
                subtitle: L10n.string("today.focus.subtitle"),
                pills: [
                    OrbitStatPill(label: L10n.string("today.pill.today"), value: "\(daytime.count)", systemImage: "sun.max"),
                    OrbitStatPill(label: L10n.string("today.pill.evening"), value: "\(evening.count)", systemImage: "moon.stars"),
                    OrbitStatPill(label: L10n.string("today.pill.overdue"), value: "\(overdueCount)", systemImage: "flag")
                ]
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if visibleTasks.isEmpty {
                EmptyStateView(
                    systemImage: "sun.max",
                    title: L10n.string("today.empty.title"),
                    subtitle: L10n.string("today.empty.subtitle")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                if !overdueTasks.isEmpty {
                    Section {
                        ForEach(overdueTasks) { task in
                            taskRow(task) {
                                scheduleForToday(task)
                            } leadingLabel: {
                                Label("Today", systemImage: "sun.max")
                            }
                            .tint(.blue)
                        }
                    } header: {
                        sectionHeader("Overdue", count: overdueTasks.count)
                    }
                }

                if !daytime.isEmpty {
                    Section {
                        ForEach(daytime) { task in
                            taskRow(task) {
                                moveToEvening(task)
                            } leadingLabel: {
                                Label("Evening", systemImage: "moon.stars")
                            }
                            .tint(.indigo)
                        }
                    } header: {
                        sectionHeader(L10n.string("today.section.today"), count: daytime.count)
                    }
                }

                if !evening.isEmpty {
                    Section {
                        ForEach(evening) { task in
                            taskRow(task) {
                                moveToDaytime(task)
                            } leadingLabel: {
                                Label("Today", systemImage: "sun.max")
                            }
                            .tint(.blue)
                        }
                    } header: {
                        sectionHeader(L10n.string("today.section.evening"), count: evening.count)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .orbitScreenChrome()
        .navigationTitle(L10n.string("nav.today"))
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
        .onChange(of: visibleTasks.count) { _, newCount in
            if newCount == 0 {
                selection.removeAll()
                editMode?.wrappedValue = .inactive
            }
        }
        .sheet(isPresented: $showAdd) {
            TaskEditorSheet(mode: .create(initialBucket: .today))
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
                    TodayQuickAddBar(
                        text: $quickText,
                        defaultEvening: $defaultEvening,
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

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func taskRow<LeadingLabel: View>(
        _ task: OrbitTask,
        leadingAction: @escaping () -> Void,
        @ViewBuilder leadingLabel: @escaping () -> LeadingLabel
    ) -> some View {
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
                Button(action: leadingAction) {
                    leadingLabel()
                }
            }
    }

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

    private func moveToEvening(_ task: OrbitTask) {
        if task.scheduledAt == nil || task.scheduledAt.map({ !Calendar.current.isDateInToday($0) }) == true {
            task.scheduledAt = Date()
        }
        task.isEvening = true
        task.listOverride = .none
        task.touch()
        try? modelContext.save()
    }

    private func moveToDaytime(_ task: OrbitTask) {
        if task.scheduledAt == nil || task.scheduledAt.map({ !Calendar.current.isDateInToday($0) }) == true {
            task.scheduledAt = Date()
        }
        task.isEvening = false
        task.listOverride = .none
        task.touch()
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

            let scheduledAt: Date = extraction.date ?? Date()
            let isEvening = extraction.isEveningHint ? true : defaultEvening

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

    private func selectedTodayTasks() -> [OrbitTask] {
        visibleTasks.filter { selection.contains($0.id) }
    }

    private func batchComplete() {
        for t in selectedTodayTasks() {
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
        for t in selectedTodayTasks() {
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
        for t in selectedTodayTasks() {
            t.scheduledAt = now
            t.isEvening = true
            t.listOverride = .none
            t.touch()
        }
        try? modelContext.save()
        selection.removeAll()
    }

    private func batchDelete() {
        for t in selectedTodayTasks() {
            NotificationManager.shared.cancelReminder(for: t.id)
            modelContext.delete(t)
        }
        try? modelContext.save()
        selection.removeAll()
    }
}

// MARK: - Today Quick Add Bar (file-private)

private struct TodayQuickAddBar: View {
    @Binding var text: String
    @Binding var defaultEvening: Bool
    let focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                defaultEvening.toggle()
            } label: {
                Image(systemName: defaultEvening ? "moon.stars" : "sun.max")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(defaultEvening ? L10n.string("quickadd.default.evening") : L10n.string("quickadd.default.today"))

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
