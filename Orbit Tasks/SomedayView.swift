import SwiftUI
import SwiftData

struct SomedayView: View {
    private struct TaskGroup: Identifiable {
        let id: String
        let title: String
        let tasks: [OrbitTask]
    }

    @Environment(\.modelContext) private var modelContext
    @State private var showAddTask = false

    @Query(
        filter: #Predicate<OrbitTask> { task in task.isCompleted == false },
        sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)]
    )
    private var openTasks: [OrbitTask]

    private var somedayTasks: [OrbitTask] {
        openTasks
            .filter { $0.scheduledAt == nil && $0.listOverride == .someday }
            .sorted {
                if ($0.project?.name ?? "") != ($1.project?.name ?? "") {
                    return ($0.project?.name ?? "") < ($1.project?.name ?? "")
                }
                return $0.createdAt > $1.createdAt
            }
    }

    private var groups: [TaskGroup] {
        let grouped = Dictionary(grouping: somedayTasks) { task in
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
                    systemImage: "archivebox",
                    title: "Nothing in Someday",
                    subtitle: "Deferred tasks will wait here."
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
                                Button { moveToAnytime(task) } label: {
                                    Label("Anytime", systemImage: "tray.and.arrow.down")
                                }
                                .tint(.teal)

                                Button { scheduleForTomorrow(task) } label: {
                                    Label("Tomorrow", systemImage: "calendar.badge.plus")
                                }
                                .tint(.green)
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
        .navigationTitle("Someday")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTask = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            TaskEditorSheet(mode: .create(initialBucket: .someday))
        }
        .orbitBannerPlacement()
    }

    private func complete(_ task: OrbitTask) {
        TaskCompletionEngine.complete(task, in: modelContext)
    }

    private func moveToAnytime(_ task: OrbitTask) {
        task.listOverride = .none
        task.touch()
        try? modelContext.save()
        TaskHaptics.light()
    }

    private func scheduleForTomorrow(_ task: OrbitTask) {
        let calendar = DateHelpers.calendar
        let start = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        task.scheduledAt = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        task.isEvening = false
        task.listOverride = .none
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
