//
//  ReviewView.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//

import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
    private var allTasks: [OrbitTask]

    private var openTasks: [OrbitTask] { allTasks.filter { !$0.isCompleted } }

    // Inbox = unscheduled + no project + no override
    private var inbox: [OrbitTask] {
        openTasks.filter { $0.scheduledAt == nil && $0.project == nil && $0.listOverride == .none }
    }

    private var overdue: [OrbitTask] {
        let now = Date()
        return openTasks
            .filter { t in
                if let d = t.deadlineAt { return d < now }
                return false
            }
            .sorted { ($0.deadlineAt ?? .distantFuture) < ($1.deadlineAt ?? .distantFuture) }
    }

    private var staleInbox: [OrbitTask] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return inbox.filter { $0.updatedAt < cutoff }
    }

    private var unblockedToday: [OrbitTask] {
        let cal = Calendar.current
        return openTasks.filter { t in
            guard let s = t.scheduledAt, cal.isDateInToday(s) else { return false }
            return t.blockStartAt == nil || t.blockDurationMinutes == nil
        }
    }

    var body: some View {
        List {
            Section("Quick stats") {
                statRow("Inbox", value: "\(inbox.count)")
                statRow("Stale inbox (>7d)", value: "\(staleInbox.count)")
                statRow("Overdue", value: "\(overdue.count)")
                statRow("Today missing blocks", value: "\(unblockedToday.count)")
            }

            if !overdue.isEmpty {
                Section("Overdue") {
                    ForEach(overdue.prefix(30)) { task in
                        reviewRow(task, subtitle: dueSubtitle(task))
                    }
                }
            }

            if !staleInbox.isEmpty {
                Section("Stale inbox") {
                    ForEach(staleInbox.prefix(30)) { task in
                        reviewRow(task, subtitle: "Last updated \(relativeDate(task.updatedAt))")
                    }
                }
            }

            if !unblockedToday.isEmpty {
                Section("Today: add blocks") {
                    ForEach(unblockedToday.prefix(30)) { task in
                        reviewRow(task, subtitle: "No time block")
                            .swipeActions(edge: .leading) {
                                Button { addBlock(task, minutes: 30) } label: {
                                    Label("30m", systemImage: "clock.badge.plus")
                                }
                                .tint(.blue)

                                Button { addBlock(task, minutes: 60) } label: {
                                    Label("60m", systemImage: "clock.badge.plus")
                                }
                                .tint(.indigo)
                            }
                    }
                }
            }

            if inbox.isEmpty == false {
                Section("Inbox triage") {
                    ForEach(inbox.prefix(30)) { task in
                        reviewRow(task, subtitle: "Unsorted")
                    }
                }
            }
        }
        .navigationTitle("Review")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Schedule stale inbox → Today") { scheduleStaleInboxToToday() }
                    Button("Clear all list overrides", role: .destructive) { clearAllOverrides() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Row

    private func reviewRow(_ task: OrbitTask, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TaskRowView(task: task, onToggleDone: {
                TaskCompletionEngine.complete(task, in: modelContext)
            }, onOpen: {
                TaskEditorCoordinator.shared.present(task: task)
            })

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(task) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            // Things-like quick triage
            Button { scheduleToday(task, evening: false) } label: {
                Label("Today", systemImage: "sun.max")
            }
            .tint(.blue)

            Button { scheduleTomorrow(task) } label: {
                Label("Tomorrow", systemImage: "calendar.badge.plus")
            }
            .tint(.green)

            Button { scheduleToday(task, evening: true) } label: {
                Label("Evening", systemImage: "moon.stars")
            }
            .tint(.indigo)

            Button { moveToSomeday(task) } label: {
                Label("Someday", systemImage: "archivebox")
            }
            .tint(.gray)
        }
        .contextMenu {
            Button("Open") { TaskEditorCoordinator.shared.present(task: task) }

            Divider()

            Button("Today") { scheduleToday(task, evening: false) }
            Button("This Evening") { scheduleToday(task, evening: true) }
            Button("Tomorrow") { scheduleTomorrow(task) }
            Button("Someday (unschedule)") { moveToSomeday(task) }

            Divider()

            if task.listOverride == .none {
                Button("Hide from Inbox (override)") { setOverride(task, value: .plan) }
            } else {
                Button("Clear override") { setOverride(task, value: .none) }
            }

            Divider()

            Button(role: .destructive) { delete(task) } label: {
                Text("Delete")
            }
        }
    }

    // MARK: - Actions

    private func scheduleToday(_ task: OrbitTask, evening: Bool) {
        task.scheduledAt = Date()
        task.isEvening = evening
        task.listOverride = .none
        task.touch()
        save()
    }

    private func scheduleTomorrow(_ task: OrbitTask) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: start)!
        // Default to 9am tomorrow (feels more “planned”)
        let at = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow

        task.scheduledAt = at
        task.isEvening = false
        task.listOverride = .none
        task.touch()
        save()
    }

    private func moveToSomeday(_ task: OrbitTask) {
        task.scheduledAt = nil
        task.isEvening = false
        task.listOverride = .someday
        task.blockStartAt = nil
        task.blockDurationMinutes = nil
        task.touch()
        save()
    }

    private func addBlock(_ task: OrbitTask, minutes: Int) {
        // If no start, default to next quarter-hour from now
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = comps.minute ?? 0
        let rounded = ((minute + 14) / 15) * 15

        var start = cal.date(bySettingHour: comps.hour ?? 9, minute: rounded % 60, second: 0, of: now) ?? now
        if rounded >= 60 {
            start = cal.date(byAdding: .hour, value: 1, to: start) ?? start
        }

        task.blockStartAt = task.blockStartAt ?? start
        task.blockDurationMinutes = minutes
        task.touch()
        save()
    }

    private func setOverride(_ task: OrbitTask, value: OrbitListOverride) {
        task.listOverride = value
        task.touch()
        save()
    }

    private func delete(_ task: OrbitTask) {
        NotificationManager.shared.cancelReminder(for: task.id)
        modelContext.delete(task)
        save()
    }

    // MARK: - Batch

    private func scheduleStaleInboxToToday() {
        guard !staleInbox.isEmpty else { return }
        let now = Date()
        for t in staleInbox {
            t.scheduledAt = now
            t.isEvening = false
            t.listOverride = .none
            t.touch()
        }
        save()
        TaskHaptics.success()
    }

    private func clearAllOverrides() {
        // Only affects tasks that currently have overrides set.
        let affected = openTasks.filter { $0.listOverride != .none }
        guard !affected.isEmpty else { return }
        for t in affected {
            t.listOverride = .none
            t.touch()
        }
        save()
    }

    // MARK: - Helpers

    private func save() {
        try? modelContext.save()
    }

    private func statRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func dueSubtitle(_ task: OrbitTask) -> String? {
        guard let due = task.deadlineAt else { return nil }
        return "Due \(relativeDate(due))"
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
