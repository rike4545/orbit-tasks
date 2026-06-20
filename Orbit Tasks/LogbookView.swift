import SwiftUI
import SwiftData

struct LogbookView: View {
    private struct DayGroup: Identifiable {
        let id: Date
        let title: String
        let tasks: [OrbitTask]
    }

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
    private var allTasks: [OrbitTask]

    private var completedTasks: [OrbitTask] {
        allTasks
            .filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    private var groupedTasks: [DayGroup] {
        let calendar = DateHelpers.calendar
        let grouped = Dictionary(grouping: completedTasks) { task in
            calendar.startOfDay(for: task.completedAt ?? task.updatedAt)
        }

        return grouped.keys.sorted(by: >).map { day in
            DayGroup(
                id: day,
                title: sectionTitle(for: day),
                tasks: (grouped[day] ?? []).sorted {
                    ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt)
                }
            )
        }
    }

    var body: some View {
        List {
            if groupedTasks.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "Logbook is empty",
                    subtitle: "Completed tasks will collect here."
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedTasks) { group in
                    Section {
                        ForEach(group.tasks) { task in
                            TaskRowView(task: task, onToggleDone: { reopen(task) }, onOpen: {
                                TaskEditorCoordinator.shared.present(task: task)
                            })
                            .swipeActions(edge: .leading) {
                                Button { reopen(task) } label: {
                                    Label("Reopen", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
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
        .navigationTitle("Logbook")
        .orbitBannerPlacement()
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = DateHelpers.calendar
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }
        return DateHelpers.dayString(day)
    }

    private func reopen(_ task: OrbitTask) {
        task.isCompleted = false
        task.completedAt = nil
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
