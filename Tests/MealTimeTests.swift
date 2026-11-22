// LoopFollow
// MealTimeTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct MealTimeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    @Test("a late-evening time picked just after midnight is yesterday")
    func lateEveningAfterMidnight() {
        let resolved = MealTime.nearestDate(to: date(22, 23, 50), now: date(22, 0, 10), calendar: calendar)
        #expect(resolved == date(21, 23, 50))
    }

    @Test("a time just after midnight picked late in the evening is tomorrow")
    func earlyMorningBeforeMidnight() {
        let resolved = MealTime.nearestDate(to: date(22, 0, 10), now: date(22, 23, 50), calendar: calendar)
        #expect(resolved == date(23, 0, 10))
    }

    @Test("an hour ahead stays today")
    func hourAhead() {
        let resolved = MealTime.nearestDate(to: date(22, 13, 0), now: date(22, 12, 0), calendar: calendar)
        #expect(resolved == date(22, 13, 0))
    }

    @Test("an hour back stays today")
    func hourBack() {
        let resolved = MealTime.nearestDate(to: date(22, 11, 0), now: date(22, 12, 0), calendar: calendar)
        #expect(resolved == date(22, 11, 0))
    }

    @Test("the seconds come from now")
    func secondsFromNow() {
        let resolved = MealTime.nearestDate(to: date(22, 11, 0, 0), now: date(22, 12, 0, 37), calendar: calendar)
        #expect(resolved == date(22, 11, 0, 37))
    }
}
