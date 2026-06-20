import SwiftUI
import SwiftData

struct AnytimeView: View {
    private struct TaskGroup: Identifiable {
        let id: String
        let title: String
        let tasks: [OrbitTask]
    }

    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<OrbitTask> { task in task.isCompleted == false },
        sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)]
    )
    private var openTasks: [OrbitTask]

    private var availableTasks: [OrbitTask] {
        openTasks
            .filter { $0.scheduledAt == nil && $0.listOverride != .someday }
            .sorted {
                if ($0.project?.name ?? "") != ($1.project?.name ?? "") {
                    return ($0.project?.name ?? "") < ($1.project?.name ?? "")
                }
                return $0.createdAt > $1.createdAt
            }
    }

    private var groups: [TaskGroup] {
        let grouped = Dictionary(grouping: availableTasks) { task in
            task.project?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        let keys = grouped.keys.sorted { lhs, rhs in
            if lhs.isEmpty { return true }
            if rhs.isEmpty { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return keys.map { key in
            TaskGroup(
                id: key.isEmpty ? "__inbox" : key,
                title: key.isEmpty ? "Inbox" : key,
                tasks: (grouped[key] ?? []).sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                EmptyStateView(
                    systemImage: "tray.and.arrow.down",
                    title: "Nothing available",
                    subtitle: "Unscheduled open tasks will appear here."
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.tasks) { task in
                            TaskRowView(task: task, onToggleDone: { complete(task) }, onOpen: {
                                TaskEditorCoordinator.shared.present(task: task)
                            })
                            .swipeActions(edge: .leading) {
                                Button { scheduleForToday(task) } label: {
                                    Label("Today", systemImage: "sun.max")
                                }
                                .tint(.blue)

                                Button { moveToSomeday(task) } label: {
                                    Label("Someday", systemImage: "archivebox")
                                }
                                .tint(.gray)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text("\(group.tasks.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Anytime")
        .orbitBannerPlacement()
    }

    private func complete(_ task: OrbitTask) {
        TaskCompletionEngine.complete(task, in: modelContext)
    }

    private func scheduleForToday(_ task: OrbitTask) {
        task.scheduledAt = Date()
        task.isEvening = false
        task.listOverride = .none
        task.touch()
        try? modelContext.save()
        TaskHaptics.light()
    }

    private func moveToSomeday(_ task: OrbitTask) {
        task.scheduledAt = nil
        task.isEvening = false
        task.listOverride = .someday
        task.blockStartAt = nil
        task.blockDurationMinutes = nil
        task.touch()
        try? modelContext.save()
        TaskHaptics.light()
    }

    private func delete(_ task: OrbitTask) {
        NotificationManager.shared.cancelReminder(for: task.id)
        modelContext.delete(task)
        try? modelContext.save()
    }
}
