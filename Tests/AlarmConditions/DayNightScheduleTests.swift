// LoopFollow
// DayNightScheduleTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct DayNightScheduleTests {
    private func config(day: (Int, Int), night: (Int, Int)) -> AlarmConfiguration {
        var c = AlarmConfiguration.default
        c.dayStart = TimeOfDay(hour: day.0, minute: day.1)
        c.nightStart = TimeOfDay(hour: night.0, minute: night.1)
        return c
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    private func lowAlarm(active: ActiveOption) -> Alarm {
        var alarm = Alarm.low(belowBG: 80, persistentMinutes: 0)
        alarm.activeOption = active
        return alarm
    }

    private func lowData(endingAt now: Date) -> AlarmData {
        let readings = [60, 60, 60].enumerated().map { i, v in
            GlucoseValue(sgv: v, date: now.addingTimeInterval(-Double(2 - i) * 300))
        }
        return AlarmData.withGlucose(readings: readings)
    }

    // MARK: - isNight

    @Test("evening night start: night wraps past midnight")
    func eveningNightStart() {
        let c = config(day: (7, 0), night: (22, 0))

        #expect(!c.isNight(at: at(7, 0)))
        #expect(!c.isNight(at: at(12, 0)))
        #expect(!c.isNight(at: at(21, 59)))
        #expect(c.isNight(at: at(22, 0)))
        #expect(c.isNight(at: at(0, 0)))
        #expect(c.isNight(at: at(6, 59)))
    }

    @Test("night start at midnight: night is only 00:00 until day start")
    func midnightNightStart() {
        let c = config(day: (7, 0), night: (0, 0))

        #expect(c.isNight(at: at(0, 0)))
        #expect(c.isNight(at: at(3, 30)))
        #expect(c.isNight(at: at(6, 59)))
        #expect(!c.isNight(at: at(7, 0)))
        #expect(!c.isNight(at: at(12, 0)))
        #expect(!c.isNight(at: at(23, 59)))
    }

    @Test("night start after midnight but before day start")
    func earlyMorningNightStart() {
        let c = config(day: (7, 0), night: (1, 30))

        #expect(!c.isNight(at: at(0, 45)))
        #expect(c.isNight(at: at(1, 30)))
        #expect(c.isNight(at: at(6, 59)))
        #expect(!c.isNight(at: at(7, 0)))
    }

    // MARK: - shouldFire

    @Test("day-only alarm fires during the day when night starts at midnight")
    func dayAlarmFiresWithMidnightNightStart() {
        let c = config(day: (7, 0), night: (0, 0))
        let now = at(12, 0)

        #expect(LowBGCondition().shouldFire(alarm: lowAlarm(active: .day), data: lowData(endingAt: now), now: now, config: c))
    }

    @Test("day-only alarm is held back at night when night starts at midnight")
    func dayAlarmHeldAtNightWithMidnightNightStart() {
        let c = config(day: (7, 0), night: (0, 0))
        let now = at(3, 0)

        #expect(!LowBGCondition().shouldFire(alarm: lowAlarm(active: .day), data: lowData(endingAt: now), now: now, config: c))
    }

    @Test("night-only alarm follows the same schedule")
    func nightAlarmWithMidnightNightStart() {
        let c = config(day: (7, 0), night: (0, 0))
        let night = at(3, 0)
        let day = at(12, 0)

        #expect(LowBGCondition().shouldFire(alarm: lowAlarm(active: .night), data: lowData(endingAt: night), now: night, config: c))
        #expect(!LowBGCondition().shouldFire(alarm: lowAlarm(active: .night), data: lowData(endingAt: day), now: day, config: c))
    }
}
