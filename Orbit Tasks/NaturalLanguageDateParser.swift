//
//  NaturalLanguageDateParser.swift
//  Orbit Tasks
//
//  Lightweight "Things-style" date/time extraction for task titles.
//  Swift 6 - iOS 17+
//
//  Example inputs:
//   - "Buy coffee tomorrow"
//   - "Pay rent on Jan 5"
//   - "Call mom next Monday at 3pm"
//   - "Submit report 2026-01-17 14:30"
//   - "Dentist 1/5/26 9am"
//   - "Workout tonight"
//   - "In 2 days at noon"
//
//  Returns:
//   - date: extracted Date? (nil if none)
//   - cleanTitle: title with the recognized date/time phrase removed
//

import Foundation

enum NaturalLanguageDateParser {

    struct Extraction: Sendable {
        let date: Date?
        let cleanTitle: String
        let matchedText: String?
        let isEveningHint: Bool
        let hadTime: Bool

        init(date: Date?, cleanTitle: String, matchedText: String? = nil, isEveningHint: Bool = false, hadTime: Bool = false) {
            self.date = date
            self.cleanTitle = cleanTitle
            self.matchedText = matchedText
            self.isEveningHint = isEveningHint
            self.hadTime = hadTime
        }
    }

    // MARK: - Public API

    static func extractDate(
        from input: String,
        baseDate: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> Extraction {
        let original = input
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Extraction(date: nil, cleanTitle: "")
        }

        var cal = calendar
        cal.timeZone = timeZone

        // We may remove multiple ranges (date + time).
        var removalRanges: [NSRange] = []
        var matchedPieces: [String] = []

        // 1) Try to extract an explicit DATE.
        let dateMatch = findDateMatch(in: trimmed, baseDate: baseDate, calendar: cal, locale: locale)
        var day: Date? = dateMatch?.day
        var isEveningHint = dateMatch?.isEveningHint ?? false

        if let r = dateMatch?.range {
            removalRanges.append(r)
            if let s = substring(trimmed, nsRange: r) { matchedPieces.append(s) }
        }

        // 2) Try to extract a TIME (can exist with or without a date).
        let timeMatch = findTimeMatch(in: trimmed, locale: locale)
        var hadTime = false
        var timeHM: (h: Int, m: Int)? = nil

        if let tm = timeMatch {
            hadTime = true
            timeHM = tm.time
            removalRanges.append(tm.range)
            if let s = substring(trimmed, nsRange: tm.range) { matchedPieces.append(s) }

            // If we saw "tonight"/"evening" words in the time phrase, keep hint.
            isEveningHint = isEveningHint || tm.isEveningHint
        }

        // 3) If only time was found, choose today (or tomorrow if time already passed).
        if day == nil, let t = timeHM {
            let candidateToday = combine(day: baseDate, time: t, calendar: cal)
            if candidateToday <= baseDate.addingTimeInterval(-60) {
                day = cal.date(byAdding: .day, value: 1, to: baseDate)
            } else {
                day = baseDate
            }
        }

        // 4) If we found a day but no time, choose a sensible default time.
        var finalDate: Date? = nil
        if let d = day {
            if let t = timeHM {
                finalDate = combine(day: d, time: t, calendar: cal)
            } else if let forced = dateMatch?.forcedTime {
                finalDate = combine(day: d, time: forced, calendar: cal)
                hadTime = true
            } else {
                let defaultTime = defaultTimeForNoExplicitTime(isEveningHint: isEveningHint)
                finalDate = combine(day: d, time: defaultTime, calendar: cal)
            }
        }

        // 5) Clean the title by removing matched ranges and surrounding connectors.
        let cleaned = cleanTitleByRemoving(trimmed, ranges: removalRanges)

        let matchedText = matchedPieces.isEmpty
            ? nil
            : matchedPieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        return Extraction(
            date: finalDate,
            cleanTitle: cleaned,
            matchedText: matchedText,
            isEveningHint: isEveningHint,
            hadTime: hadTime
        )
    }

    // MARK: - Date matching

    private struct DateMatch {
        let day: Date
        let range: NSRange
        let isEveningHint: Bool
        let forcedTime: (h: Int, m: Int)?
    }

    private static func findDateMatch(in text: String, baseDate: Date, calendar: Calendar, locale: Locale) -> DateMatch? {
        // Prefer most explicit formats first.
        if let m = matchISODate(in: text, calendar: calendar) { return m }
        if let m = matchYearMonthDay(in: text, calendar: calendar) { return m }
        if let m = matchChineseMonthDay(in: text, baseDate: baseDate, calendar: calendar) { return m }
        if let m = matchNumericDate(in: text, baseDate: baseDate, calendar: calendar, locale: locale) { return m }
        if let m = matchMonthNameDate(in: text, baseDate: baseDate, calendar: calendar) { return m }
        if let m = matchWeekday(in: text, baseDate: baseDate, calendar: calendar) { return m }
        if let m = matchRelativeInX(in: text, baseDate: baseDate, calendar: calendar) { return m }
        if let m = matchKeywords(in: text, baseDate: baseDate, calendar: calendar) { return m }
        return nil
    }

    // ISO: 2026-01-17
    private static func matchISODate(in text: String, calendar: Calendar) -> DateMatch? {
        let pattern = #"(?i)\b(\d{4})-(\d{2})-(\d{2})\b"#
        guard let match = firstMatchResult(pattern, in: text),
              let year = intCapture(match, 1, in: text),
              let month = intCapture(match, 2, in: text),
              let day = intCapture(match, 3, in: text),
              let date = makeValidatedDate(year: year, month: month, day: day, calendar: calendar)
        else { return nil }

        return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
    }

    // 2026/1/17, 2026.1.17, 2026年1月17日
    private static func matchYearMonthDay(in text: String, calendar: Calendar) -> DateMatch? {
        let patterns = [
            #"(?i)\b(\d{4})[\/\.-](\d{1,2})[\/\.-](\d{1,2})\b"#,
            #"(?iu)\b(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?\b"#
        ]

        for pattern in patterns {
            guard let match = firstMatchResult(pattern, in: text),
                  let year = intCapture(match, 1, in: text),
                  let month = intCapture(match, 2, in: text),
                  let day = intCapture(match, 3, in: text),
                  let date = makeValidatedDate(year: year, month: month, day: day, calendar: calendar)
            else { continue }

            return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
        }
        return nil
    }

    // 1月5日
    private static func matchChineseMonthDay(in text: String, baseDate: Date, calendar: Calendar) -> DateMatch? {
        let pattern = #"(?iu)\b(\d{1,2})\s*月\s*(\d{1,2})\s*日?\b"#
        guard let match = firstMatchResult(pattern, in: text),
              let month = intCapture(match, 1, in: text),
              let day = intCapture(match, 2, in: text),
              let date = makeDateWithCurrentOrNextYear(month: month, day: day, baseDate: baseDate, calendar: calendar)
        else { return nil }

        return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
    }

    // Numeric: 1/5, 05-01-2026, etc (region-aware day/month ordering).
    private static func matchNumericDate(in text: String, baseDate: Date, calendar: Calendar, locale: Locale) -> DateMatch? {
        let pattern = #"(?iu)\b(\d{1,2})[\/\.-](\d{1,2})(?:[\/\.-](\d{2,4}))?\b"#
        guard let match = firstMatchResult(pattern, in: text),
              let first = intCapture(match, 1, in: text),
              let second = intCapture(match, 2, in: text)
        else { return nil }

        let dayFirst = prefersDayFirstNumericDate(for: locale)
        let month = dayFirst ? second : first
        let day = dayFirst ? first : second

        if let rawYear = intCapture(match, 3, in: text) {
            let year = normalizeYear(rawYear, relativeTo: baseDate, calendar: calendar)
            guard let date = makeValidatedDate(year: year, month: month, day: day, calendar: calendar) else {
                return nil
            }
            return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
        }

        guard let date = makeDateWithCurrentOrNextYear(month: month, day: day, baseDate: baseDate, calendar: calendar) else {
            return nil
        }
        return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
    }

    // Month names: Jan 5 / 5 Jan / 5 janvier / 5 januari
    private static func matchMonthNameDate(in text: String, baseDate: Date, calendar: Calendar) -> DateMatch? {
        let monthFirstPattern = #"(?iu)\b([\p{L}\.]+)\s+(\d{1,2})(?:st|nd|rd|th|er)?(?:,?\s*(\d{2,4}))?\b"#
        let dayFirstPattern = #"(?iu)\b(\d{1,2})(?:st|nd|rd|th|er)?\s+([\p{L}\.]+)(?:,?\s*(\d{2,4}))?\b"#

        let monthFirst = firstMonthNameCandidate(
            pattern: monthFirstPattern,
            monthGroup: 1,
            dayGroup: 2,
            yearGroup: 3,
            in: text,
            baseDate: baseDate,
            calendar: calendar
        )

        let dayFirst = firstMonthNameCandidate(
            pattern: dayFirstPattern,
            monthGroup: 2,
            dayGroup: 1,
            yearGroup: 3,
            in: text,
            baseDate: baseDate,
            calendar: calendar
        )

        switch (monthFirst, dayFirst) {
        case let (a?, b?):
            return a.range.location <= b.range.location ? a : b
        case let (a?, nil):
            return a
        case let (nil, b?):
            return b
        default:
            return nil
        }
    }

    private static func firstMonthNameCandidate(
        pattern: String,
        monthGroup: Int,
        dayGroup: Int,
        yearGroup: Int,
        in text: String,
        baseDate: Date,
        calendar: Calendar
    ) -> DateMatch? {
        for match in allMatches(pattern, in: text) {
            guard let monthToken = capture(match, monthGroup, in: text),
                  let month = monthIndex(from: monthToken),
                  let day = intCapture(match, dayGroup, in: text)
            else { continue }

            let date: Date?
            if let rawYear = intCapture(match, yearGroup, in: text) {
                let year = normalizeYear(rawYear, relativeTo: baseDate, calendar: calendar)
                date = makeValidatedDate(year: year, month: month, day: day, calendar: calendar)
            } else {
                date = makeDateWithCurrentOrNextYear(month: month, day: day, baseDate: baseDate, calendar: calendar)
            }

            if let d = date {
                return DateMatch(day: d, range: match.range, isEveningHint: false, forcedTime: nil)
            }
        }
        return nil
    }

    // Weekday: monday / lundi prochain / volgende maandag / 下周一
    private static func matchWeekday(in text: String, baseDate: Date, calendar: Calendar) -> DateMatch? {
        if let chinese = matchChineseWeekday(in: text, baseDate: baseDate, calendar: calendar) {
            return chinese
        }

        let pattern = #"(?iu)\b(?:(next|this|ce|cette|volgende|deze)\s+)?([\p{L}\.]{2,12})(?:\s+(prochain|suivant|volgende))?\b"#
        for match in allMatches(pattern, in: text) {
            guard let weekdayToken = capture(match, 2, in: text),
                  let weekday = weekdayIndex(from: weekdayToken)
            else { continue }

            let leading = capture(match, 1, in: text).map(normalizedToken)
            let trailing = capture(match, 3, in: text).map(normalizedToken)
            let modifierToken = trailing ?? leading
            let modifier: String?
            if let token = modifierToken, nextModifierTokens.contains(token) {
                modifier = "next"
            } else if let token = modifierToken, thisModifierTokens.contains(token) {
                modifier = "this"
            } else {
                modifier = nil
            }

            let target = nextWeekday(weekday, from: baseDate, calendar: calendar, modifier: modifier)
            return DateMatch(day: target, range: match.range, isEveningHint: false, forcedTime: nil)
        }

        return nil
    }

    private static func matchChineseWeekday(in text: String, baseDate: Date, calendar: Calendar) -> DateMatch? {
        let pattern = #"(?iu)(?:(下|这|這)\s*)?(?:周|週|星期|礼拜|禮拜)\s*([一二三四五六日天])"#
        guard let match = firstMatchResult(pattern, in: text),
              let dayToken = capture(match, 2, in: text),
              let weekday = weekdayIndexFromChinese(dayToken)
        else { return nil }

        let prefix = capture(match, 1, in: text) ?? ""
        let modifier: String?
        if prefix == "下" {
            modifier = "next"
        } else if prefix == "这" || prefix == "這" {
            modifier = "this"
        } else {
            modifier = nil
        }

        let target = nextWeekday(weekday, from: baseDate, calendar: calendar, modifier: modifier)
        return DateMatch(day: target, range: match.range, isEveningHint: false, forcedTime: nil)
    }

    // Relative: in 2 days / dans 2 jours / over 2 dagen / 2天后
    private static func matchRelativeInX(in text: String, baseDate: Date, calendar: Calendar) -> DateMatch? {
        // English
        let english = #"(?iu)\b(in)\s+(\d+)\s+(minute|minutes|min|mins|hour|hours|hr|hrs|day|days|week|weeks|month|months)\b"#
        if let match = firstMatchResult(english, in: text),
           let value = intCapture(match, 2, in: text),
           let unit = capture(match, 3, in: text) {
            if let date = addRelative(value: value, unitToken: unit, baseDate: baseDate, calendar: calendar) {
                return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
            }
        }

        // French + Dutch
        let frNl = #"(?iu)\b(?:dans|over)\s+(\d+)\s+(minute|minuten|minuut|minutes?|heure|heures|uur|uren|dag|dagen|jour|jours|semaine|semaines|week|weken|mois|maand|maanden)\b"#
        if let match = firstMatchResult(frNl, in: text),
           let value = intCapture(match, 1, in: text),
           let unit = capture(match, 2, in: text) {
            if let date = addRelative(value: value, unitToken: unit, baseDate: baseDate, calendar: calendar) {
                return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
            }
        }

        // Chinese
        let chinese = #"(?iu)(\d+)\s*(分钟|分鐘|小时|小時|天|周|週|星期|个月|個月|月)\s*(?:后|後)"#
        if let match = firstMatchResult(chinese, in: text),
           let value = intCapture(match, 1, in: text),
           let unit = capture(match, 2, in: text) {
            if let date = addRelative(value: value, unitToken: unit, baseDate: baseDate, calendar: calendar) {
                return DateMatch(day: date, range: match.range, isEveningHint: false, forcedTime: nil)
            }
        }

        return nil
    }

    // Keywords: today/tomorrow/tonight + localized equivalents.
    private static func matchKeywords(in text: String, baseDate: Date, calendar: Calendar) -> DateMatch? {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate

        // Order matters: longer phrases first.
        let options: [(String, (Date, Bool, (Int, Int)?))] = [
            (#"(?iu)\bthis\s+evening\b"#, (baseDate, true, (18, 0))),
            (#"(?iu)\btonight\b|\bce\s+soir\b|\bvanavond\b|今晚|今夜"#, (baseDate, true, (19, 0))),
            (#"(?iu)\bevening\b|\bsoir(?:ee|ée)?\b|\bavond\b|晚上"#, (baseDate, true, (18, 0))),
            (#"(?iu)\btomorrow\b|\btmrw\b|\btmr\b|\bdemain\b|\bmorgen\b|明天"#, (tomorrow, false, nil)),
            (#"(?iu)\btoday\b|\baujourd[’']hui\b|\bvandaag\b|今天"#, (baseDate, false, nil)),
            (#"(?iu)\bnext\s+week\b|\bsemaine\s+prochaine\b|\bvolgende\s+week\b|下(?:周|週|星期|礼拜|禮拜)"#, (nextWeek, false, nil))
        ]

        for (pattern, payload) in options {
            if let match = firstMatchResult(pattern, in: text) {
                let (day, evening, forcedTime) = payload
                return DateMatch(day: day, range: match.range, isEveningHint: evening, forcedTime: forcedTime)
            }
        }
        return nil
    }

    // MARK: - Time matching

    private struct TimeMatch {
        let time: (h: Int, m: Int)
        let range: NSRange
        let isEveningHint: Bool
    }

    private static func findTimeMatch(in text: String, locale _: Locale) -> TimeMatch? {
        // Common words (localized)
        if let r = firstMatch(#"(?iu)\bnoon\b|\bmidi\b|正午|中午"#, in: text) {
            return TimeMatch(time: (12, 0), range: r, isEveningHint: false)
        }
        if let r = firstMatch(#"(?iu)\bmidnight\b|\bminuit\b|午夜"#, in: text) {
            return TimeMatch(time: (0, 0), range: r, isEveningHint: true)
        }

        // Chinese meridiem + hour: "下午3点", "上午9:30"
        let chineseMeridiem = #"(?iu)(上午|下午|中午|晚上|早上|凌晨)\s*(\d{1,2})(?:[:：点點时時](\d{1,2}))?\s*(?:分|分钟|分鐘)?"#
        if let match = firstMatchResult(chineseMeridiem, in: text),
           let marker = capture(match, 1, in: text),
           let rawHour = intCapture(match, 2, in: text) {
            let minute = intCapture(match, 3, in: text) ?? 0
            if let parsed = parseChineseTime(hour: rawHour, minute: minute, marker: marker) {
                return TimeMatch(time: parsed.time, range: match.range, isEveningHint: parsed.eveningHint)
            }
        }

        // Chinese explicit clock marker: "3点", "15时30分"
        let chineseClock = #"(?iu)(\d{1,2})\s*[点點时時](\d{1,2})?\s*(?:分|分钟|分鐘)?"#
        if let match = firstMatchResult(chineseClock, in: text),
           let hour = intCapture(match, 1, in: text) {
            let minute = intCapture(match, 2, in: text) ?? 0
            if isValidTime(hour: hour, minute: minute) {
                return TimeMatch(time: (hour, minute), range: match.range, isEveningHint: hour >= 18)
            }
        }

        // French style "14h30"
        let frenchClock = #"(?iu)\b(\d{1,2})\s*h\s*(\d{2})?\b"#
        if let match = firstMatchResult(frenchClock, in: text),
           let hour = intCapture(match, 1, in: text) {
            let minute = intCapture(match, 2, in: text) ?? 0
            if isValidTime(hour: hour, minute: minute) {
                return TimeMatch(time: (hour, minute), range: match.range, isEveningHint: hour >= 18)
            }
        }

        // Dutch style "14u30"
        let dutchClock = #"(?iu)\b(\d{1,2})\s*u\s*(\d{2})?\b"#
        if let match = firstMatchResult(dutchClock, in: text),
           let hour = intCapture(match, 1, in: text) {
            let minute = intCapture(match, 2, in: text) ?? 0
            if isValidTime(hour: hour, minute: minute) {
                return TimeMatch(time: (hour, minute), range: match.range, isEveningHint: hour >= 18)
            }
        }

        // "at 3pm", "3pm", "3:30 pm", "15:20"
        let genericPattern = #"(?iu)\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\b"#
        for match in allMatches(genericPattern, in: text) {
            if isLikelyPartOfDateToken(text: text, range: match.range) {
                continue
            }

            guard let whole = substring(text, nsRange: match.range) else { continue }
            if whole.contains("/") || whole.contains("-") || whole.contains(".") {
                continue
            }

            guard let hourToken = intCapture(match, 1, in: text) else { continue }
            let minute = intCapture(match, 2, in: text) ?? 0
            let ampm = capture(match, 3, in: text)?.lowercased()

            var hour = hourToken
            if let ampm {
                let isPM = ampm.contains("p")
                let isAM = ampm.contains("a")
                if isPM, hour < 12 { hour += 12 }
                if isAM, hour == 12 { hour = 0 }
            }

            // Avoid grabbing years like "2026".
            if ampm == nil && minute == 0 && hourToken >= 24 {
                continue
            }

            if isValidTime(hour: hour, minute: minute) {
                let eveningHint = (ampm?.contains("p") ?? false) || (hour >= 18)
                return TimeMatch(time: (hour, minute), range: match.range, isEveningHint: eveningHint)
            }
        }

        return nil
    }

    private static func parseChineseTime(hour: Int, minute: Int, marker: String) -> (time: (Int, Int), eveningHint: Bool)? {
        guard isValidTime(hour: hour, minute: minute) else { return nil }
        var adjusted = hour

        if marker == "下午" || marker == "晚上" {
            if adjusted < 12 { adjusted += 12 }
        } else if marker == "中午" {
            if adjusted < 11 { adjusted += 12 }
        } else if marker == "上午" || marker == "早上" || marker == "凌晨" {
            if adjusted == 12 { adjusted = 0 }
        }

        guard isValidTime(hour: adjusted, minute: minute) else { return nil }
        let eveningHint = marker == "下午" || marker == "晚上" || adjusted >= 18
        return ((adjusted, minute), eveningHint)
    }

    // MARK: - Helpers

    private static func prefersDayFirstNumericDate(for locale: Locale) -> Bool {
        let region = regionCode(from: locale)
        if ["BE", "CI", "HK"].contains(region) {
            return true
        }
        if ["US", "CN"].contains(region) {
            return false
        }
        // Keep existing behavior for non-targeted regions.
        return false
    }

    private static func regionCode(from locale: Locale) -> String {
        if let region = locale.region?.identifier, !region.isEmpty {
            return region.uppercased()
        }
        if let region = locale.regionCode, !region.isEmpty {
            return region.uppercased()
        }
        let pieces = locale.identifier.split(separator: "_")
        if pieces.count >= 2 {
            return String(pieces[1]).uppercased()
        }
        return ""
    }

    private static func normalizeYear(_ year: Int, relativeTo baseDate: Date, calendar: Calendar) -> Int {
        guard year < 100 else { return year }
        let currentYear = calendar.component(.year, from: baseDate)
        let currentCentury = (currentYear / 100) * 100
        var expanded = currentCentury + year
        if expanded < (currentYear - 30) {
            expanded += 100
        }
        return expanded
    }

    private static func makeValidatedDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        comps.minute = 0
        comps.second = 0

        guard let date = calendar.date(from: comps) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    private static func makeDateWithCurrentOrNextYear(month: Int, day: Int, baseDate: Date, calendar: Calendar) -> Date? {
        let year = calendar.component(.year, from: baseDate)
        guard var date = makeValidatedDate(year: year, month: month, day: day, calendar: calendar) else {
            return nil
        }

        if date < calendar.startOfDay(for: baseDate).addingTimeInterval(-86400),
           let bumped = makeValidatedDate(year: year + 1, month: month, day: day, calendar: calendar) {
            date = bumped
        }
        return date
    }

    private static func monthIndex(from token: String) -> Int? {
        monthAliases[normalizedToken(token)]
    }

    private static func normalizedToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .autoupdatingCurrent)
            .lowercased()
    }

    private static func weekdayIndex(from token: String) -> Int? {
        weekdayAliases[normalizedToken(token)]
    }

    private static func weekdayIndexFromChinese(_ token: String) -> Int? {
        switch token {
        case "一": return 2
        case "二": return 3
        case "三": return 4
        case "四": return 5
        case "五": return 6
        case "六": return 7
        case "日", "天": return 1
        default: return nil
        }
    }

    private static func addRelative(value: Int, unitToken: String, baseDate: Date, calendar: Calendar) -> Date? {
        let unit = normalizedToken(unitToken)

        if unit.hasPrefix("min") || unit == "minuut" || unit == "minuten" || unit.contains("分") {
            return baseDate.addingTimeInterval(TimeInterval(value * 60))
        }
        if unit.hasPrefix("h") || unit.hasPrefix("uur") || unit.contains("小时") || unit.contains("小時") {
            return baseDate.addingTimeInterval(TimeInterval(value * 3600))
        }
        if unit.hasPrefix("day") || unit.hasPrefix("dag") || unit.hasPrefix("jour") || unit == "天" {
            return calendar.date(byAdding: .day, value: value, to: baseDate)
        }
        if unit.hasPrefix("week") || unit.hasPrefix("semain") || unit.hasPrefix("wee") || unit == "周" || unit == "週" || unit == "星期" {
            return calendar.date(byAdding: .day, value: value * 7, to: baseDate)
        }
        if unit.hasPrefix("month") || unit.hasPrefix("mois") || unit.hasPrefix("maand") || unit == "月" || unit == "个月" || unit == "個月" {
            return calendar.date(byAdding: .month, value: value, to: baseDate)
        }
        return nil
    }

    private static func defaultTimeForNoExplicitTime(isEveningHint: Bool) -> (h: Int, m: Int) {
        // Avoid midnight defaults; choose a sane time so UI doesn't show 12:00 AM.
        isEveningHint ? (18, 0) : (9, 0)
    }

    private static func combine(day: Date, time: (h: Int, m: Int), calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        var comps = calendar.dateComponents([.year, .month, .day], from: start)
        comps.hour = time.h
        comps.minute = time.m
        comps.second = 0
        return calendar.date(from: comps) ?? day
    }

    private static func nextWeekday(_ weekday: Int, from base: Date, calendar: Calendar, modifier: String?) -> Date {
        let start = calendar.startOfDay(for: base)

        let currentWeekday = calendar.component(.weekday, from: start)
        var daysAhead = weekday - currentWeekday
        if daysAhead < 0 { daysAhead += 7 }

        // "this Monday": if today is Monday, keep today; else next occurrence in current/next calendar week.
        // "next Monday": if Monday already passed this week, keep the upcoming Monday;
        // otherwise, push to the following week.
        if modifier == "next" {
            if daysAhead == 0 { daysAhead = 7 }
            else if weekday > currentWeekday { daysAhead += 7 }
        }

        return calendar.date(byAdding: .day, value: daysAhead, to: start) ?? start
    }

    private static func isValidTime(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }

    private static func isLikelyPartOfDateToken(text: String, range: NSRange) -> Bool {
        let ns = text as NSString
        let separators: Set<String> = ["/", "-", ".", "月", "日"]

        if range.location > 0 {
            let before = ns.substring(with: NSRange(location: range.location - 1, length: 1))
            if separators.contains(before) { return true }
        }

        let afterIndex = range.location + range.length
        if afterIndex < ns.length {
            let after = ns.substring(with: NSRange(location: afterIndex, length: 1))
            if separators.contains(after) { return true }
        }

        return false
    }

    // MARK: - Cleaning

    private static func cleanTitleByRemoving(_ text: String, ranges: [NSRange]) -> String {
        guard !ranges.isEmpty else {
            return normalizeWhitespace(text)
        }

        let ns = text as NSString
        // Sort descending so indexes remain valid.
        let sorted = ranges
            .filter { $0.location != NSNotFound && $0.length > 0 }
            .sorted { a, b in a.location > b.location }

        let working = NSMutableString(string: ns)

        for r in sorted {
            if r.location + r.length <= working.length {
                working.replaceCharacters(in: r, with: " ")
            }
        }

        // Remove connector words that often hang around after deleting date/time.
        var result = working as String
        result = removeDanglingConnectors(result)

        // Clean punctuation/extra whitespace.
        result = normalizeWhitespace(result)
        result = trimPunctuation(result)
        return result
    }

    private static func removeDanglingConnectors(_ s: String) -> String {
        let patterns = [
            #"(?iu)\b(on|at|by|due|for|le|pour|op|om|tegen|voor)\b"#,
            #"(?iu)\bà\b"#,
            #"(?iu)(?:在|于|於)\s*"#
        ]
        var out = s
        for pattern in patterns {
            out = out.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return out
    }

    private static func normalizeWhitespace(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimPunctuation(_ s: String) -> String {
        var out = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Trim stray punctuation at ends.
        while let last = out.last, [",", ".", "-", ":", ";"].contains(String(last)) {
            out.removeLast()
            out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return out
    }

    // MARK: - Regex helpers

    private static func allMatches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let ns = text as NSString
        return regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
    }

    private static func firstMatchResult(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        allMatches(pattern, in: text).first
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSRange? {
        firstMatchResult(pattern, in: text)?.range
    }

    private static func capture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return nil }
        return substring(text, nsRange: range)
    }

    private static func intCapture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> Int? {
        guard let raw = capture(match, index, in: text) else { return nil }
        return Int(raw)
    }

    private static func substring(_ text: String, nsRange: NSRange) -> String? {
        guard nsRange.location != NSNotFound, nsRange.length > 0 else { return nil }
        guard let range = Range(nsRange, in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - Dictionaries

    private static let nextModifierTokens: Set<String> = [
        "next", "prochain", "suivant", "volgende"
    ]

    private static let thisModifierTokens: Set<String> = [
        "this", "ce", "cette", "deze"
    ]

    private static let weekdayAliases: [String: Int] = [
        // English
        "sun": 1, "sunday": 1,
        "mon": 2, "monday": 2,
        "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "wednesday": 4,
        "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6,
        "sat": 7, "saturday": 7,

        // French
        "lun": 2, "lundi": 2,
        "mar": 3, "mardi": 3,
        "mer": 4, "mercredi": 4,
        "jeu": 5, "jeudi": 5,
        "ven": 6, "vendredi": 6,
        "sam": 7, "samedi": 7,
        "dim": 1, "dimanche": 1,

        // Dutch
        "ma": 2, "maandag": 2,
        "di": 3, "dinsdag": 3,
        "wo": 4, "woensdag": 4,
        "do": 5, "donderdag": 5,
        "vr": 6, "vrijdag": 6,
        "za": 7, "zaterdag": 7,
        "zo": 1, "zondag": 1
    ]

    private static let monthAliases: [String: Int] = [
        "jan": 1, "january": 1, "janvier": 1, "janv": 1, "januari": 1,
        "feb": 2, "february": 2, "fev": 2, "fevr": 2, "fevrier": 2, "februari": 2,
        "mar": 3, "march": 3, "mars": 3, "maart": 3,
        "apr": 4, "april": 4, "avr": 4,
        "may": 5, "mai": 5,
        "jun": 6, "june": 6, "juin": 6,
        "jul": 7, "july": 7, "juillet": 7, "juil": 7, "juli": 7,
        "aug": 8, "august": 8, "aout": 8,
        "sep": 9, "sept": 9, "september": 9, "septembre": 9,
        "oct": 10, "october": 10, "octobre": 10, "okt": 10, "oktober": 10,
        "nov": 11, "november": 11, "novembre": 11,
        "dec": 12, "december": 12, "decembre": 12
    ]
}
