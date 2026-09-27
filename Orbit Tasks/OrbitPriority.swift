//
//  OrbitPriority.swift
//  Orbit Tasks
//
//  Swift 6 • iOS 17+ • SwiftData
//

import Foundation
import SwiftData

// MARK: - Enums

public enum OrbitPriority: Int, CaseIterable, Codable, Hashable {
  case none = 0
  case low = 1
  case medium = 2
  case high = 3

  public var label: String {
    switch self {
    case .none: return "None"
    case .low: return "Low"
    case .medium: return "Medium"
    case .high: return "High"
    }
  }
}

public enum OrbitEnergy: Int, CaseIterable, Codable, Hashable {
  case low = 1
  case medium = 2
  case high = 3

  public var label: String {
    switch self {
    case .low: return "Low"
    case .medium: return "Medium"
    case .high: return "High"
    }
  }
}

/// Recurrence frequency for repeating tasks.
public enum OrbitRepeatFrequency: Int, CaseIterable, Codable, Hashable {
  case none = 0
  case daily = 1
  case weekly = 2
  case monthly = 3
  case yearly = 4

  public var label: String {
    switch self {
    case .none: return "None"
    case .daily: return "Daily"
    case .weekly: return "Weekly"
    case .monthly: return "Monthly"
    case .yearly: return "Yearly"
    }
  }
}

/// Optional “bucket override” (useful for inbox/today/plan UX).
public enum OrbitListOverride: Int, CaseIterable, Codable, Hashable {
  case none = 0
  case inbox = 1
  case today = 2
  case plan = 3
  case someday = 4

  public var label: String {
    switch self {
    case .none: return "None"
    case .inbox: return "Inbox"
    case .today: return "Today"
    case .plan: return "Plan"
    case .someday: return "Someday"
    }
  }
}

/// Weekday mask for “weekly on Mon/Wed/Fri”, etc.
/// Raw value uses bits 0...6 for Sun...Sat.
public struct OrbitRecurrenceWeekdayMask: OptionSet, Codable, Hashable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }

  public static let sunday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 0)
  public static let monday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 1)
  public static let tuesday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 2)
  public static let wednesday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 3)
  public static let thursday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 4)
  public static let friday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 5)
  public static let saturday = OrbitRecurrenceWeekdayMask(rawValue: 1 << 6)

  public static let weekdays: OrbitRecurrenceWeekdayMask = [
    .monday, .tuesday, .wednesday, .thursday, .friday,
  ]
  public static let weekend: OrbitRecurrenceWeekdayMask = [.saturday, .sunday]
  public static let all: OrbitRecurrenceWeekdayMask = [
    .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
  ]

  /// Calendar weekday: 1=Sunday ... 7=Saturday
  public static func fromCalendarWeekday(_ weekday: Int) -> OrbitRecurrenceWeekdayMask {
    switch weekday {
    case 1: return .sunday
    case 2: return .monday
    case 3: return .tuesday
    case 4: return .wednesday
    case 5: return .thursday
    case 6: return .friday
    case 7: return .saturday
    default: return []
    }
  }

  public func contains(calendarWeekday: Int) -> Bool {
    contains(Self.fromCalendarWeekday(calendarWeekday))
  }
}

// MARK: - Models (SwiftData infers relationships; no @Relationship macros)

@Model
public final class OrbitArea: Identifiable {
  public var id: UUID
  public var name: String
  public var createdAt: Date
  public var projects: [OrbitProject]

  public init(name: String) {
    self.id = UUID()
    self.name = name
    self.createdAt = Date()
    self.projects = []
  }
}

@Model
public final class OrbitProject: Identifiable {
  public var id: UUID
  public var name: String
  public var notes: String
  public var createdAt: Date
  public var deadlineAt: Date?

  public var area: OrbitArea?
  public var tasks: [OrbitTask]

  public init(name: String, notes: String = "", deadlineAt: Date? = nil, area: OrbitArea? = nil) {
    self.id = UUID()
    self.name = name
    self.notes = notes
    self.createdAt = Date()
    self.deadlineAt = deadlineAt
    self.area = area
    self.tasks = []
  }
}

@Model
public final class OrbitTag: Identifiable {
  public var id: UUID
  public var name: String
  public var createdAt: Date
  public var tasks: [OrbitTask]

  public init(name: String) {
    self.id = UUID()
    self.name = name
    self.createdAt = Date()
    self.tasks = []
  }
}

@Model
public final class OrbitAttachment: Identifiable {
  public var id: UUID
  public var createdAt: Date

  public var displayName: String
  public var relativePath: String
  public var uti: String

  // ✅ Stored on the model (fixes “no member indexedText/indexedAt”)
  public var indexedText: String?
  public var indexedAt: Date?

  public var task: OrbitTask?

  public init(displayName: String, relativePath: String, uti: String, task: OrbitTask? = nil) {
    self.id = UUID()
    self.createdAt = Date()
    self.displayName = displayName
    self.relativePath = relativePath
    self.uti = uti
    self.indexedText = nil
    self.indexedAt = nil
    self.task = task
  }

  // Back-compat for older code that used “ocrText” naming
  public var ocrText: String? {
    get { indexedText }
    set { indexedText = newValue }
  }

  public var ocrIndexedAt: Date? {
    get { indexedAt }
    set { indexedAt = newValue }
  }
}

@Model
public final class OrbitChecklistItem: Identifiable {
  public var id: UUID
  public var title: String
  public var isCompleted: Bool
  public var createdAt: Date
  public var updatedAt: Date
  public var sortOrder: Int

  public var task: OrbitTask?

  public init(title: String, isCompleted: Bool = false, sortOrder: Int = 0, task: OrbitTask? = nil)
  {
    self.id = UUID()
    self.title = title
    self.isCompleted = isCompleted
    let now = Date()
    self.createdAt = now
    self.updatedAt = now
    self.sortOrder = sortOrder
    self.task = task
  }

  public func touch() {
    updatedAt = Date()
  }
}

@Model
public final class OrbitTask: Identifiable {
  public var id: UUID

  public var title: String
  public var notes: String

  public var createdAt: Date
  public var updatedAt: Date

  public var isCompleted: Bool
  public var completedAt: Date?

  public var scheduledAt: Date?
  public var deadlineAt: Date?

  public var isEvening: Bool
  public var isPrivate: Bool

  public var priorityRaw: Int
  public var estimatedMinutes: Int?
  public var energyRaw: Int?

  public var blockStartAt: Date?
  public var blockDurationMinutes: Int?

  // Focus timer
  public var timerStartedAt: Date?

  // Bucket override
  public var listOverrideRaw: Int

  // Recurrence
  public var repeatFrequencyRaw: Int
  public var repeatInterval: Int
  public var repeatWeekdayMaskRaw: Int
  public var repeatEndDate: Date?

  public var project: OrbitProject?
  public var projectHeading: String?
  public var tags: [OrbitTag]
  public var attachments: [OrbitAttachment]
  @Relationship(deleteRule: .cascade, inverse: \OrbitChecklistItem.task)
  public var checklistItems: [OrbitChecklistItem]

  // ✅ Custom init prevents SwiftData’s synthesized init(backingData:) from leaking into call sites
  public init(
    title: String,
    notes: String = "",
    project: OrbitProject? = nil,
    projectHeading: String? = nil,
    scheduledAt: Date? = nil,
    deadlineAt: Date? = nil,
    isEvening: Bool = false,
    isPrivate: Bool = false,
    priority: OrbitPriority = .none,
    estimatedMinutes: Int? = nil,
    energy: OrbitEnergy? = nil,
    blockStartAt: Date? = nil,
    blockDurationMinutes: Int? = nil
  ) {
    self.id = UUID()

    self.title = title
    self.notes = notes

    let now = Date()
    self.createdAt = now
    self.updatedAt = now

    self.isCompleted = false
    self.completedAt = nil

    self.scheduledAt = scheduledAt
    self.deadlineAt = deadlineAt

    self.isEvening = isEvening
    self.isPrivate = isPrivate

    self.priorityRaw = priority.rawValue
    self.estimatedMinutes = estimatedMinutes
    self.energyRaw = energy?.rawValue

    self.blockStartAt = blockStartAt
    self.blockDurationMinutes = blockDurationMinutes

    self.timerStartedAt = nil

    self.listOverrideRaw = OrbitListOverride.none.rawValue

    self.repeatFrequencyRaw = OrbitRepeatFrequency.none.rawValue
    self.repeatInterval = 1
    self.repeatWeekdayMaskRaw = 0
    self.repeatEndDate = nil

    self.project = project
    self.projectHeading = projectHeading
    self.tags = []
    self.attachments = []
    self.checklistItems = []
  }

  // MARK: - Derived properties

  public func touch() {
    updatedAt = Date()
  }

  public var priority: OrbitPriority {
    get { OrbitPriority(rawValue: priorityRaw) ?? .none }
    set { priorityRaw = newValue.rawValue }
  }

  public var energy: OrbitEnergy? {
    get { energyRaw.flatMap { OrbitEnergy(rawValue: $0) } }
    set { energyRaw = newValue?.rawValue }
  }

  public var listOverride: OrbitListOverride {
    get { OrbitListOverride(rawValue: listOverrideRaw) ?? .none }
    set { listOverrideRaw = newValue.rawValue }
  }

  public var repeatFrequency: OrbitRepeatFrequency {
    get { OrbitRepeatFrequency(rawValue: repeatFrequencyRaw) ?? .none }
    set { repeatFrequencyRaw = newValue.rawValue }
  }

  public var repeatWeekdayMask: OrbitRecurrenceWeekdayMask {
    get { OrbitRecurrenceWeekdayMask(rawValue: repeatWeekdayMaskRaw) }
    set { repeatWeekdayMaskRaw = newValue.rawValue }
  }

  public var sortedChecklistItems: [OrbitChecklistItem] {
    checklistItems.sorted {
      if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
      return $0.createdAt < $1.createdAt
    }
  }

  public var completedChecklistCount: Int {
    checklistItems.filter(\.isCompleted).count
  }

  public var checklistProgressText: String? {
    guard !checklistItems.isEmpty else { return nil }
    return "\(completedChecklistCount)/\(checklistItems.count)"
  }

  // MARK: - Focus timer back-compat (fixes FocusNowView errors)

  public var isTimerRunning: Bool { timerStartedAt != nil }

  public func startTimer() {
    if timerStartedAt == nil {
      timerStartedAt = Date()
      touch()
    }
  }

  public func stopTimer() {
    if timerStartedAt != nil {
      timerStartedAt = nil
      touch()
    }
  }

  public func stopTimerIfNeeded() {
    stopTimer()
  }
}
