//
//  OrbitWeekdayMask.swift
//  Orbit Tasks
//
//  Created by Bryan on 1/18/26.
//

//
//  OrbitWeekdayMask.swift
//  Orbit Tasks
//

import Foundation

enum OrbitWeekdayMask {
  // Calendar weekday: 1=Sun ... 7=Sat
  static func bit(for weekday: Int) -> Int {
    let wd = min(7, max(1, weekday))
    return 1 << (wd - 1)
  }

  static func contains(_ mask: Int, weekday: Int) -> Bool {
    (mask & bit(for: weekday)) != 0
  }

  static func fromWeekdays(_ weekdays: [Int]) -> Int {
    weekdays.reduce(0) { $0 | bit(for: $1) }
  }
}
