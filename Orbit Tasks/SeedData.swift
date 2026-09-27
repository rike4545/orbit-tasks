//
//  SeedData.swift
//  Orbit Tasks
//

import Foundation
import SwiftData

@MainActor
enum SeedData {
  static func bootstrapIfNeeded(in context: ModelContext) {
    do {
      let count = try context.fetchCount(FetchDescriptor<OrbitTask>())
      guard count == 0 else { return }

      let personal = OrbitArea(name: "Personal")
      let work = OrbitArea(name: "Work")

      let errands = OrbitProject(name: "Errands", notes: "Small wins", area: personal)
      let app = OrbitProject(name: "OrbitTasks MVP", notes: "Ship the core flows", area: work)

      let tagQuick = OrbitTag(name: "Quick")
      let tagDeep = OrbitTag(name: "Deep Work")

      let now = Date()
      let startOfToday = Calendar.current.startOfDay(for: now)
      let tomorrow: Date? = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)

      // ✅ Fully labeled init to avoid "Ambiguous use of init"
      let t1 = OrbitTask(
        title: "Buy coffee beans",
        notes: "",
        project: errands,
        scheduledAt: nil,
        deadlineAt: nil,
        isEvening: false,
        priority: .low,
        estimatedMinutes: 5,
        energy: .low,
        blockStartAt: nil,
        blockDurationMinutes: nil
      )
      t1.tags.append(tagQuick)

      let t2 = OrbitTask(
        title: "Write project outline",
        notes: "Calm by default; power mode optional.",
        project: app,
        scheduledAt: now,
        deadlineAt: nil,
        isEvening: false,
        priority: .medium,
        estimatedMinutes: 45,
        energy: .high,
        blockStartAt: nil,
        blockDurationMinutes: nil
      )
      t2.tags.append(tagDeep)

      let t3 = OrbitTask(
        title: "Plan tomorrow",
        notes: "",
        project: nil,
        scheduledAt: tomorrow,
        deadlineAt: nil,
        isEvening: true,
        priority: .low,
        estimatedMinutes: 10,
        energy: .low,
        blockStartAt: nil,
        blockDurationMinutes: nil
      )

      context.insert(personal)
      context.insert(work)
      context.insert(errands)
      context.insert(app)
      context.insert(tagQuick)
      context.insert(tagDeep)
      context.insert(t1)
      context.insert(t2)
      context.insert(t3)

      try context.save()
    } catch {
      // seed failures shouldn't crash
    }
  }
}
