//
//  TaskEditorCoordinator.swift
//  Orbit Tasks
//
//  Global edit-sheet coordinator
//  Swift 6 • iOS 17+
//

import Combine
import SwiftUI

@MainActor
final class TaskEditorCoordinator: ObservableObject {
  static let shared = TaskEditorCoordinator()

  @Published var editingTask: OrbitTask? = nil

  private init() {}

  func present(task: OrbitTask) {
    editingTask = task
  }

  func dismiss() {
    editingTask = nil
  }

  /// Put this once near the root of your UI (e.g., RootView overlay)
  @ViewBuilder
  func sheetPresenter() -> some View {
    EmptyView()
      .sheet(
        item: Binding(
          get: { self.editingTask },
          set: { self.editingTask = $0 }
        )
      ) { task in
        TaskEditorSheet(mode: .edit(task: task))
      }
  }
}
