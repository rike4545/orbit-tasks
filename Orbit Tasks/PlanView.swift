//
//  PlanView.swift
//  Orbit Tasks
//
//  Plan = scheduled and deadline-dated tasks + Someday
//  Adds bottom Quick Add with NLP date parsing
//

import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @Query(
        filter: #Predicate<OrbitTask> { t in t.isCompleted == false },
        sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)]
    )
    private var openTasks: [OrbitTask]

    @State private var showAdd = false
    @State private var newTaskDate: Date? = nil
    @State private var selection: Set<UUID> = []

    // Quick Add
    @State private var quickText: String = ""
    @State private var defaultTomorrow: Bool = false
    @FocusState private var quickFocused: Bool

    private var planned: [OrbitTask] {
        openTasks
            .filter { plannedDate(for: $0) != nil && $0.listOverride != .someday }
            .sorted {
                let a = plannedDate(for: $0) ?? .distantFuture
                let b = plannedDate(for: $1) ?? .distantFuture
                if a != b { return a < b }
                return $0.createdAt < $1.createdAt
            }
    }

    private var someday: [OrbitTask] {
        openTasks
            .filter { $0.scheduledAt == nil && $0.listOverride == .someday }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var nextSevenDaysCount: Int {
        let now = Date()
        let inSeven = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? .distantFuture
        return planned.filter { task in
            guard let date = plannedDate(for: task) else { return false }
            return date >= now && date <= inSeven
        }.count
    }

    private var deadlineCount: Int {
        planned.filter { $0.deadlineAt != nil }.count
    }

    private var editableTaskCount: Int {
        planned.count + someday.count
    }

    private var hasEditableTasks: Bool {
        editableTaskCount > 0
    }

    var body: some View {
        List(selection: $selection) {
            OrbitFocusHeader(
                title: L10n.string("plan.focus.title"),
                subtitle: L10n.string("plan.focus.subtitle"),
                pills: [
                    OrbitStatPill(label: L10n.string("plan.pill.scheduled"), value: "\(planned.count)", systemImage: "calendar"),
                    OrbitStatPill(label: L10n.string("plan.pill.seven_day"), value: "\(nextSevenDaysCount)", systemImage: "calendar.badge.clock"),
                    OrbitStatPill(label: L10n.string("plan.pill.deadlines"), value: "\(deadlineCount)", systemImage: "flag"),
                    OrbitStatPill(label: L10n.string("plan.pill.someday"), value: "\(someday.count)", systemImage: "archivebox")
                ]
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            let grouped = Dictionary(grouping: planned) { task in
                Calendar.current.startOfDay(for: plannedDate(for: task) ?? .distantPast)
            }
            let days = grouped.keys.sorted()

            if days.isEmpty {
                EmptyStateView(
                    systemImage: "calendar",
                    title: L10n.string("plan.empty.title"),
                    subtitle: L10n.string("plan.empty.subtitle")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(days, id: \.self) { day in
                    let dayTasks = (grouped[day] ?? []).sorted {
                        if $0.isEvening != $1.isEvening { return $0.isEvening == false }
                        let a = plannedDate(for: $0) ?? .distantFuture
                        let b = plannedDate(for: $1) ?? .distantFuture
                        if a != b { return a < b }
                        return $0.createdAt < $1.createdAt
                    }

                    Section {
                        ForEach(dayTasks) { task in
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
                                    Button { moveToSomeday(task) } label: {
                                        Label("Someday", systemImage: "archivebox")
                                    }
                                    .tint(.gray)
                                }
                        }
                    } header: {
                        HStack {
                            Text(sectionTitle(for: day))
                            Spacer()
                            Button {
                                newTaskDate = defaultTaskDate(for: day)
                                showAdd = true
                            } label: {
                                Image(systemName: "plus.circle")
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Add task to \(sectionTitle(for: day))")

                            NavigationLink {
                                TimelineDayView(day: day, tasks: dayTasks)
                            } label: {
                                Image(systemName: "clock")
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                if someday.isEmpty {
                    Text("Nothing here. Great.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(someday) { task in
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
                                Button { scheduleForTomorrow(task) } label: {
                                    Label("Tomorrow", systemImage: "calendar.badge.plus")
                                }
                                .tint(.green)
                            }
                    }
                }
            } header: {
                HStack {
                    Text(L10n.string("plan.section.someday"))
                    Spacer()
                    Text("\(someday.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .orbitScreenChrome()
        .navigationTitle(L10n.string("nav.plan"))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if hasEditableTasks {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newTaskDate = nil
                    showAdd = true
                } label: {
                    Label(L10n.string("common.add"), systemImage: "plus")
                }
            }
        }
        .onChange(of: editableTaskCount) { _, newCount in
            if newCount == 0 {
                selection.removeAll()
                editMode?.wrappedValue = .inactive
            }
        }
        .sheet(isPresented: $showAdd, onDismiss: {
            newTaskDate = nil
        }) {
            if let newTaskDate {
                TaskEditorSheet(mode: .create(initialBucket: .scheduled(newTaskDate)))
            } else {
                TaskEditorSheet(mode: .create(initialBucket: .plan))
            }
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
                    PlanQuickAddBar(
                        text: $quickText,
                        defaultTomorrow: $defaultTomorrow,
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

    private func plannedDate(for task: OrbitTask) -> Date? {
        task.scheduledAt ?? task.deadlineAt
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = DateHelpers.calendar
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInTomorrow(day) {
            return "Tomorrow"
        }

        let startOfToday = calendar.startOfDay(for: Date())
        let dayOffset = calendar.dateComponents([.day], from: startOfToday, to: day).day ?? 0
        if dayOffset > 1 && dayOffset < 7 {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.calendar = calendar
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            return formatter.string(from: day)
        }

        return DateHelpers.dayString(day)
    }

    private func defaultTaskDate(for day: Date) -> Date {
        DateHelpers.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
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

    private func moveToSomeday(_ task: OrbitTask) {
        task.scheduledAt = nil
        task.isEvening = false
        task.listOverride = .someday
        task.blockStartAt = nil
        task.blockDurationMinutes = nil
        task.touch()
        try? modelContext.save()
    }

    private func scheduleForTomorrow(_ task: OrbitTask) {
        task.scheduledAt = tomorrow(atHour: 9, minute: 0)
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
                guard defaultTomorrow else { return nil }
                return tomorrow(atHour: 9, minute: 0)
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
            if scheduledAt == nil {
                task.listOverride = .someday
            }
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

    private func tomorrow(atHour hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let t = cal.date(byAdding: .day, value: 1, to: start)!
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: t) ?? t
    }

    // MARK: - Batch

    private func selectedPlanTasks() -> [OrbitTask] {
        openTasks.filter { selection.contains($0.id) }
    }

    private func batchComplete() {
        for t in selectedPlanTasks() {
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
        for t in selectedPlanTasks() {
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
        for t in selectedPlanTasks() {
            t.scheduledAt = now
            t.isEvening = true
            t.listOverride = .none
            t.touch()
        }
        try? modelContext.save()
        selection.removeAll()
    }

    private func batchDelete() {
        for t in selectedPlanTasks() {
            NotificationManager.shared.cancelReminder(for: t.id)
            modelContext.delete(t)
        }
        try? modelContext.save()
        selection.removeAll()
    }
}

// MARK: - Plan Quick Add Bar (file-private)

private struct PlanQuickAddBar: View {
    @Binding var text: String
    @Binding var defaultTomorrow: Bool
    let focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                defaultTomorrow.toggle()
            } label: {
                Image(systemName: defaultTomorrow ? "calendar.badge.plus" : "archivebox")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(defaultTomorrow ? L10n.string("quickadd.default.tomorrow") : L10n.string("quickadd.default.someday"))

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
