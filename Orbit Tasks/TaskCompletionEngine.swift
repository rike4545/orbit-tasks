import Foundation
import SwiftData

@MainActor
enum TaskCompletionEngine {

  static func complete(_ task: OrbitTask, in modelContext: ModelContext) {
    let now = Date()

    task.isCompleted = true
    task.completedAt = now
    for item in task.checklistItems {
      item.isCompleted = true
      item.touch()
    }
    task.stopTimerIfNeeded()
    task.touch()

    // If you have reminders, these exist in your project already (used elsewhere)
    NotificationManager.shared.cancelReminder(for: task.id)

    // Repeat handling: create the next instance (simple, predictable)
    if let next = nextRepeatDate(for: task, base: now) {
      let newTask = OrbitTask(
        title: task.title,
        notes: task.notes,
        project: task.project,
        projectHeading: task.projectHeading,
        scheduledAt: next,
        deadlineAt: nil,
        isEvening: task.isEvening,
        isPrivate: task.isPrivate,
        priority: task.priority,
        estimatedMinutes: task.estimatedMinutes,
        energy: task.energy,
        blockStartAt: nil,
        blockDurationMinutes: nil
      )

      // Carry recurrence forward
      newTask.repeatFrequency = task.repeatFrequency
      newTask.repeatInterval = max(1, task.repeatInterval)
      newTask.repeatWeekdayMask = task.repeatWeekdayMask
      newTask.repeatEndDate = task.repeatEndDate

      // Carry tags (not attachments)
      newTask.tags.append(contentsOf: task.tags)
      for (index, item) in task.sortedChecklistItems.enumerated() {
        let copiedItem = OrbitChecklistItem(
          title: item.title,
          isCompleted: false,
          sortOrder: index,
          task: newTask
        )
        newTask.checklistItems.append(copiedItem)
      }

      modelContext.insert(newTask)

      // Optional: schedule a reminder for the new one
      if let when = newTask.deadlineAt ?? newTask.scheduledAt {
        Task {
          await NotificationManager.shared.scheduleReminder(
            for: newTask.id, title: newTask.title, at: when)
        }
      }
    }

    try? modelContext.save()
    TaskHaptics.success()
    OrbitInterstitialAdManager.shared.recordTaskCompletionEvent()
  }

  // MARK: - Next occurrence

  private static func nextRepeatDate(for task: OrbitTask, base: Date) -> Date? {
    let freq = task.repeatFrequency
    guard freq != .none else { return nil }

    let interval = max(1, task.repeatInterval)
    let cal = Calendar.current

    // Use scheduledAt if present, else fall back to base
    let anchor = task.scheduledAt ?? base

    var candidate: Date?

    switch freq {
    case .daily:
      candidate = cal.date(byAdding: .day, value: interval, to: anchor)

    case .weekly:
      let mask = task.repeatWeekdayMask
      if mask.isEmpty {
        candidate = cal.date(byAdding: .day, value: 7 * interval, to: anchor)
      } else {
        // Search within the next interval window for the next matching weekday
        let start = cal.startOfDay(for: anchor)
        let maxDays = 7 * interval
        for offset in 1...maxDays {
          guard let d = cal.date(byAdding: .day, value: offset, to: start) else { continue }
          let weekday = cal.component(.weekday, from: d)  // 1..7
          if mask.contains(calendarWeekday: weekday) {
            // Keep time-of-day from anchor if it had one
            candidate = combine(day: d, timeLike: anchor, calendar: cal)
            break
          }
        }
        if candidate == nil {
          candidate = cal.date(byAdding: .day, value: maxDays, to: anchor)
        }
      }

    case .monthly:
      candidate = cal.date(byAdding: .month, value: interval, to: anchor)

    case .yearly:
      candidate = cal.date(byAdding: .year, value: interval, to: anchor)

    case .none:
      candidate = nil
    }

    guard let next = candidate else { return nil }

    if let end = task.repeatEndDate, next > end {
      return nil
    }

    return next
  }

  private static func combine(day: Date, timeLike: Date, calendar: Calendar) -> Date {
    let dayStart = calendar.startOfDay(for: day)
    let t = calendar.dateComponents([.hour, .minute, .second], from: timeLike)

    var comps = calendar.dateComponents([.year, .month, .day], from: dayStart)
    comps.hour = t.hour
    comps.minute = t.minute
    comps.second = t.second ?? 0
    return calendar.date(from: comps) ?? day
  }
}
