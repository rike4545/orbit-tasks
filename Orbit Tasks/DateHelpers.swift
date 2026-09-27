//
//  DateHelpers 2.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/17/26.
//

//
//  DateHelpers.swift
//  Orbit Tasks
//

import Foundation

enum DateHelpers {
  static var calendar: Calendar {
    var cal = Calendar.autoupdatingCurrent
    cal.locale = Locale.autoupdatingCurrent
    return cal
  }

  static func localePrefers24HourTime(locale: Locale = .autoupdatingCurrent) -> Bool {
    guard let hourFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)
    else {
      return false
    }
    return !hourFormat.contains("a")
  }

  static func startOfDay(_ date: Date) -> Date {
    calendar.startOfDay(for: date)
  }

  static func isToday(_ date: Date) -> Bool {
    calendar.isDateInToday(date)
  }

  static func isTomorrow(_ date: Date) -> Bool {
    calendar.isDateInTomorrow(date)
  }

  static func dayString(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    let f = DateFormatter()
    f.locale = locale
    f.calendar = calendar
    f.dateStyle = .full
    f.timeStyle = .none
    return f.string(from: date)
  }

  static func shortDayString(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    let f = DateFormatter()
    f.locale = locale
    f.calendar = calendar
    f.setLocalizedDateFormatFromTemplate("MMM d")
    return f.string(from: date)
  }

  static func relativeDayString(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    let cal = calendar
    if cal.isDateInToday(date) {
      return "Today"
    }
    if cal.isDateInTomorrow(date) {
      return "Tomorrow"
    }
    if cal.isDateInYesterday(date) {
      return "Yesterday"
    }

    let today = cal.startOfDay(for: Date())
    let day = cal.startOfDay(for: date)
    let offset = cal.dateComponents([.day], from: today, to: day).day ?? 0
    if offset > 1 && offset < 7 {
      let f = DateFormatter()
      f.locale = locale
      f.calendar = cal
      f.setLocalizedDateFormatFromTemplate("EEEE")
      return f.string(from: date)
    }

    return shortDayString(date, locale: locale)
  }

  static func timeString(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    let use24 = UserDefaults.standard.object(forKey: "orbit.use24HourTime") as? Bool ?? false

    let f = DateFormatter()
    f.locale = locale
    f.calendar = calendar

    if use24 {
      f.setLocalizedDateFormatFromTemplate("Hm")
    } else {
      f.dateStyle = .none
      f.timeStyle = .short
    }

    return f.string(from: date)
  }

  static func compactDateTimeString(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
    if calendar.isDateInToday(date) {
      return timeString(date, locale: locale)
    }
    return "\(relativeDayString(date, locale: locale)) \(timeString(date, locale: locale))"
  }

  static func hourGridLabel(hour: Int, on day: Date, locale: Locale = .autoupdatingCurrent)
    -> String
  {
    let clampedHour = max(0, min(23, hour))
    let start = calendar.startOfDay(for: day)
    let tick = calendar.date(byAdding: .hour, value: clampedHour, to: start) ?? start

    let f = DateFormatter()
    f.locale = locale
    f.calendar = calendar

    let use24 = UserDefaults.standard.object(forKey: "orbit.use24HourTime") as? Bool ?? false
    if use24 {
      f.setLocalizedDateFormatFromTemplate("HH:mm")
    } else {
      f.setLocalizedDateFormatFromTemplate("j")
    }

    return f.string(from: tick)
  }
}
