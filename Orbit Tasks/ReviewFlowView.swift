//
//  ReviewFlowView.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/18/26.
//

//
//  ReviewFlowView.swift
//  Orbit Tasks
//

import SwiftData
import SwiftUI

struct ReviewFlowView: View {
  @Environment(\.modelContext) private var modelContext

  @Query(sort: [SortDescriptor(\OrbitTask.updatedAt, order: .reverse)])
  private var allTasks: [OrbitTask]

  private var openTasks: [OrbitTask] { allTasks.filter { !$0.isCompleted } }

  private var inbox: [OrbitTask] {
    openTasks.filter { $0.scheduledAt == nil && $0.project == nil && $0.listOverride == .none }
  }

  private var overdue: [OrbitTask] {
    let now = Date()
    return
      openTasks
      .filter { ($0.deadlineAt ?? .distantFuture) < now }
      .sorted { ($0.deadlineAt ?? .distantFuture) < ($1.deadlineAt ?? .distantFuture) }
  }

  private var staleInbox: [OrbitTask] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    return inbox.filter { $0.updatedAt < cutoff }
  }

  private var needsTags: [OrbitTask] {
    openTasks.filter { $0.tags.isEmpty }
  }

  private var needsProject: [OrbitTask] {
    inbox.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  enum Step: Int, CaseIterable {
    case overdue, staleInbox, needsProject, needsTags, done

    var title: String {
      switch self {
      case .overdue: return L10n.string("review.step.overdue")
      case .staleInbox: return L10n.string("review.step.stale_inbox")
      case .needsProject: return L10n.string("review.step.needs_project")
      case .needsTags: return L10n.string("review.step.needs_tags")
      case .done: return L10n.string("review.step.done")
      }
    }
  }

  @State private var step: Step = .overdue

  var body: some View {
    List {
      Section(step.title) {
        switch step {
        case .overdue:
          taskList(overdue, empty: L10n.string("review.empty.overdue"))
        case .staleInbox:
          taskList(staleInbox, empty: L10n.string("review.empty.stale_inbox"))
        case .needsProject:
          taskList(needsProject, empty: L10n.string("review.empty.needs_project"))
        case .needsTags:
          taskList(needsTags, empty: L10n.string("review.empty.needs_tags"))
        case .done:
          Text(L10n.string("review.empty.done"))
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(L10n.string("nav.review"))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(step == .done ? L10n.string("common.restart") : L10n.string("common.next")) {
          if step == .done {
            step = .overdue
            return
          }
          let nextRaw = min(step.rawValue + 1, Step.done.rawValue)
          step = Step(rawValue: nextRaw) ?? .done
        }
      }
    }
    .orbitBannerPlacement()
  }

  @ViewBuilder
  private func taskList(_ tasks: [OrbitTask], empty: String) -> some View {
    if tasks.isEmpty {
      Text(empty).foregroundStyle(.secondary)
    } else {
      ForEach(tasks.prefix(40)) { task in
        TaskRowView(
          task: task,
          onToggleDone: {
            TaskCompletionEngine.complete(task, in: modelContext)
          },
          onOpen: {
            TaskEditorCoordinator.shared.present(task: task)
          })
      }
    }
  }
}
