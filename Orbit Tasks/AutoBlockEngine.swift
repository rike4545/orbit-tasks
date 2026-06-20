//
//  AutoBlockEngine.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/18/26.
//


//
//  AutoBlockEngine.swift
//  Orbit Tasks
//

import Foundation

enum AutoBlockEngine {

    struct Window {
        let startHour: Int
        let endHour: Int
    }

    struct Suggestion {
        let start: Date
        let minutes: Int
    }

    static func suggestBlocks(
        for tasks: [OrbitTask],
        day: Date,
        calendar: Calendar = .current,
        dayWindows: [Window] = [Window(startHour: 9, endHour: 12), Window(startHour: 13, endHour: 17)],
        eveningWindows: [Window] = [Window(startHour: 19, endHour: 21)]
    ) -> [UUID: Suggestion] {

        let startOfDay = calendar.startOfDay(for: day)

        // Only tasks scheduled that day and missing blocks
        let candidates = tasks
            .filter { t in
                guard let s = t.scheduledAt else { return false }
                return calendar.isDate(s, inSameDayAs: day) && (t.blockStartAt == nil || t.blockDurationMinutes == nil)
            }
            .sorted { a, b in
                // Higher priority first, then higher energy, then longer tasks
                if a.priorityRaw != b.priorityRaw { return a.priorityRaw > b.priorityRaw }
                if (a.energyRaw ?? 0) != (b.energyRaw ?? 0) { return (a.energyRaw ?? 0) > (b.energyRaw ?? 0) }
                return (a.estimatedMinutes ?? 30) > (b.estimatedMinutes ?? 30)
            }

        // Build occupied intervals from existing blocks
        var occupied: [(Date, Date)] = tasks.compactMap { t in
            guard let s = t.blockStartAt, let m = t.blockDurationMinutes else { return nil }
            return (s, s.addingTimeInterval(TimeInterval(m * 60)))
        }
        occupied.sort { $0.0 < $1.0 }

        func overlaps(_ a: (Date, Date), _ b: (Date, Date)) -> Bool {
            a.0 < b.1 && b.0 < a.1
        }

        func isFree(_ interval: (Date, Date)) -> Bool {
            for o in occupied {
                if overlaps(interval, o) { return false }
            }
            return true
        }

        func addOccupied(_ interval: (Date, Date)) {
            occupied.append(interval)
            occupied.sort { $0.0 < $1.0 }
        }

        func windowSlots(for window: Window) -> [(Date, Date)] {
            let ws = calendar.date(bySettingHour: window.startHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            let we = calendar.date(bySettingHour: window.endHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            return [(ws, we)]
        }

        var suggestions: [UUID: Suggestion] = [:]

        for task in candidates {
            let minutes = max(10, task.estimatedMinutes ?? 30)
            let windows = task.isEvening ? eveningWindows : dayWindows

            var placed: Suggestion? = nil

            for w in windows {
                for (ws, we) in windowSlots(for: w) {
                    var cursor = ws
                    while cursor.addingTimeInterval(TimeInterval(minutes * 60)) <= we {
                        let interval = (cursor, cursor.addingTimeInterval(TimeInterval(minutes * 60)))
                        if isFree(interval) {
                            placed = Suggestion(start: cursor, minutes: minutes)
                            addOccupied(interval)
                            break
                        }
                        cursor = cursor.addingTimeInterval(15 * 60) // 15-min grid
                    }
                    if placed != nil { break }
                }
                if placed != nil { break }
            }

            if let placed {
                suggestions[task.id] = placed
            }
        }

        return suggestions
    }
}
