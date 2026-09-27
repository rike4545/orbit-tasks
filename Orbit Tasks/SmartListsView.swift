import SwiftData
//
//  SmartListsView.swift
//  Orbit Tasks
import SwiftUI

struct SmartListsView: View {
  @Environment(\.modelContext) private var modelContext

  @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
  private var allTasks: [OrbitTask]

  private var open: [OrbitTask] { allTasks.filter { !$0.isCompleted } }

  struct SmartList: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let predicate: ([OrbitTask]) -> [OrbitTask]
  }

  private var lists: [SmartList] {
    let cal = Calendar.current
    let now = Date()
    return [
      SmartList(title: "Overdue", systemImage: "exclamationmark.triangle") { tasks in
        tasks.filter { ($0.deadlineAt ?? .distantFuture) < now }
          .sorted { ($0.deadlineAt ?? .distantFuture) < ($1.deadlineAt ?? .distantFuture) }
      },
      SmartList(title: "Due Soon (7d)", systemImage: "calendar.badge.clock") { tasks in
        let end = cal.date(byAdding: .day, value: 7, to: now) ?? now
        return tasks.filter { d in
          guard let dl = d.deadlineAt else { return false }
          return dl >= now && dl <= end
        }
        .sorted { ($0.deadlineAt ?? .distantFuture) < ($1.deadlineAt ?? .distantFuture) }
      },
      SmartList(title: "Quick Wins", systemImage: "bolt") { tasks in
        tasks.filter { ($0.estimatedMinutes ?? 999) <= 15 }
      },
      SmartList(title: "Deep Work", systemImage: "brain") { tasks in
        tasks.filter {
          ($0.energyRaw ?? 0) >= OrbitEnergy.high.rawValue || ($0.estimatedMinutes ?? 0) >= 60
        }
      },
      SmartList(title: "No Project", systemImage: "folder.badge.questionmark") { tasks in
        tasks.filter { $0.project == nil }
      },
      SmartList(title: "No Tags", systemImage: "tag.slash") { tasks in
        tasks.filter { $0.tags.isEmpty }
      },
      SmartList(title: "Has Attachments", systemImage: "paperclip") { tasks in
        tasks.filter { !$0.attachments.isEmpty }
      },
      SmartList(title: "Private", systemImage: "lock") { tasks in
        tasks.filter { $0.isPrivate }
      },
    ]
  }

  var body: some View {
    List {
      ForEach(lists) { list in
        let items = list.predicate(open)
        NavigationLink {
          SmartListDetailView(title: list.title, tasks: items)
        } label: {
          HStack {
            Label(list.title, systemImage: list.systemImage)
            Spacer()
            Text("\(items.count)")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle("Smart Lists")
    .orbitBannerPlacement()
  }
}

private struct SmartListDetailView: View {
  @Environment(\.modelContext) private var modelContext
  let title: String
  let tasks: [OrbitTask]

  var body: some View {
    List {
      if tasks.isEmpty {
        Text("Nothing here.")
          .foregroundStyle(.secondary)
      } else {
        ForEach(tasks) { task in
          TaskRowView(task: task) {
            TaskCompletionEngine.complete(task, in: modelContext)
          }
          .contentShape(Rectangle())
          .onTapGesture {
            TaskEditorCoordinator.shared.present(task: task)
          }
        }
      }
    }
    .navigationTitle(title)
    .orbitBannerPlacement()
  }
}
