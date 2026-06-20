//
//  AutoPlanner.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//


import Foundation
import SwiftData

@MainActor
enum AutoPlanner {

    struct Config {
        var startHour: Int = 9
        var endHour: Int = 17
        var breakMinutesEvery: Int = 90
        var breakMinutes: Int = 10
        var defaultTaskMinutes: Int = 30
    }

    static func applyPlanForToday(tasks: [OrbitTask], config: Config, modelContext: ModelContext) {
        let cal = Calendar.current
        let dayStart = cal.date(bySettingHour: config.startHour, minute: 0, second: 0, of: Date()) ?? Date()
        let dayEnd = cal.date(bySettingHour: config.endHour, minute: 0, second: 0, of: Date()) ?? Date()

        // Candidates: today tasks that are not already blocked
        var candidates = tasks.filter { t in
            guard !t.isCompleted else { return false }
            guard let s = t.scheduledAt, cal.isDateInToday(s) else { return false }
            return t.blockStartAt == nil || t.blockDurationMinutes == nil
        }

        // Sort: priority desc, then energy high first (AM bias), then shortest estimate first
        candidates.sort {
            if $0.priorityRaw != $1.priorityRaw { return $0.priorityRaw > $1.priorityRaw }
            let e0 = $0.energyRaw ?? 0
            let e1 = $1.energyRaw ?? 0
            if e0 != e1 { return e0 > e1 }
            return ($0.estimatedMinutes ?? 9999) < ($1.estimatedMinutes ?? 9999)
        }

        var cursor = dayStart
        var workedSinceBreak = 0

        for task in candidates {
            let minutes = max(5, task.estimatedMinutes ?? config.defaultTaskMinutes)
            let duration = TimeInterval(minutes * 60)

            // Insert breaks
            if config.breakMinutesEvery > 0, workedSinceBreak >= config.breakMinutesEvery {
                cursor = cursor.addingTimeInterval(TimeInterval(config.breakMinutes * 60))
                workedSinceBreak = 0
            }

            // Stop if out of time
            if cursor.addingTimeInterval(duration) > dayEnd { break }

            task.blockStartAt = cursor
            task.blockDurationMinutes = minutes
            task.touch()

            cursor = cursor.addingTimeInterval(duration)
            workedSinceBreak += minutes
        }

        try? modelContext.save()
        TaskHaptics.success()
    }
}
