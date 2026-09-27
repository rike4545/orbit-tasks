//
//  Orbit_TasksTests.swift
//  Orbit TasksTests
//
//  Created by Bryan on 1/16/26.
//

import Foundation
import Testing

@testable import Orbit_Tasks

struct Orbit_TasksTests {

  @Test func usNumericDateStaysMonthFirst() throws {
    let calendar = makeCalendar()
    let base = makeDate(2026, 2, 1, 10, 0, calendar: calendar)

    let extraction = NaturalLanguageDateParser.extractDate(
      from: "Pay rent 1/5",
      baseDate: base,
      calendar: calendar,
      timeZone: calendar.timeZone,
      locale: Locale(identifier: "en_US")
    )

    let date = try #require(extraction.date)
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    #expect(c.year == 2027)
    #expect(c.month == 1)
    #expect(c.day == 5)
  }

  @Test func belgiumNumericDateUsesDayFirst() throws {
    let calendar = makeCalendar()
    let base = makeDate(2026, 2, 1, 10, 0, calendar: calendar)

    let extraction = NaturalLanguageDateParser.extractDate(
      from: "Betaal huur 1/5",
      baseDate: base,
      calendar: calendar,
      timeZone: calendar.timeZone,
      locale: Locale(identifier: "nl_BE")
    )

    let date = try #require(extraction.date)
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    #expect(c.year == 2026)
    #expect(c.month == 5)
    #expect(c.day == 1)
  }

  @Test func coteDIvoireFrenchKeywordParsesTomorrow() throws {
    let calendar = makeCalendar()
    let base = makeDate(2026, 2, 1, 10, 0, calendar: calendar)

    let extraction = NaturalLanguageDateParser.extractDate(
      from: "Appeler le client demain",
      baseDate: base,
      calendar: calendar,
      timeZone: calendar.timeZone,
      locale: Locale(identifier: "fr_CI")
    )

    let date = try #require(extraction.date)
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    #expect(c.year == 2026)
    #expect(c.month == 2)
    #expect(c.day == 2)
  }

  @Test func coteDIvoireNumericDateUsesDayFirst() throws {
    let calendar = makeCalendar()
    let base = makeDate(2026, 2, 1, 10, 0, calendar: calendar)

    let extraction = NaturalLanguageDateParser.extractDate(
      from: "Payer facture 1/5",
      baseDate: base,
      calendar: calendar,
      timeZone: calendar.timeZone,
      locale: Locale(identifier: "fr_CI")
    )

    let date = try #require(extraction.date)
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    #expect(c.year == 2026)
    #expect(c.month == 5)
    #expect(c.day == 1)
  }

  @Test func hongKongTraditionalChineseParsesWeekdayAndTime() throws {
    let calendar = makeCalendar()
    let base = makeDate(2026, 2, 4, 9, 0, calendar: calendar)  // Wednesday

    let extraction = NaturalLanguageDateParser.extractDate(
      from: "提交報告 下週一 下午3點",
      baseDate: base,
      calendar: calendar,
      timeZone: calendar.timeZone,
      locale: Locale(identifier: "zh_Hant_HK")
    )

    let date = try #require(extraction.date)
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    #expect(c.year == 2026)
    #expect(c.month == 2)
    #expect(c.day == 9)
    #expect(c.hour == 15)
    #expect(c.minute == 0)
  }

  @Test func mainlandChinaParsesChineseYmdAndTime() throws {
    let calendar = makeCalendar()
    let base = makeDate(2026, 2, 1, 10, 0, calendar: calendar)

    let extraction = NaturalLanguageDateParser.extractDate(
      from: "提交发票 2026年3月5日 上午9点",
      baseDate: base,
      calendar: calendar,
      timeZone: calendar.timeZone,
      locale: Locale(identifier: "zh_Hans_CN")
    )

    let date = try #require(extraction.date)
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    #expect(c.year == 2026)
    #expect(c.month == 3)
    #expect(c.day == 5)
    #expect(c.hour == 9)
    #expect(c.minute == 0)
  }

  // MARK: - Helpers

  private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
  }

  private func makeDate(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, calendar: Calendar
  ) -> Date {
    var comps = DateComponents()
    comps.calendar = calendar
    comps.timeZone = calendar.timeZone
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = 0
    return calendar.date(from: comps) ?? .distantPast
  }
}
