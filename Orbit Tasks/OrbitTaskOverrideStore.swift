//
//  OrbitTaskOverrideStore.swift
//  Orbit Tasks
//

import Combine
import Foundation
import SwiftData

@MainActor
final class OrbitTaskOverrideStore: ObservableObject {

  // Some toolchains require an explicit publisher when you have no @Published properties.
  let objectWillChange = ObservableObjectPublisher()

  func setOverride(
    _ overrideValue: OrbitListOverride, for task: OrbitTask, in context: ModelContext
  ) {
    objectWillChange.send()
    task.listOverride = overrideValue
    task.touch()
    try? context.save()
  }

  func clearOverride(for task: OrbitTask, in context: ModelContext) {
    objectWillChange.send()
    task.listOverride = .none
    task.touch()
    try? context.save()
  }
}
