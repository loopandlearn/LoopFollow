// LoopFollow
// ScheduledBasalSegmentsTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct ScheduledBasalSegmentsTests {
    private let schedule: [ProfileManager.TimeValue<Double>] = [
        .init(timeAsSeconds: 0, value: 0.2),
        .init(timeAsSeconds: 4 * 3600, value: 0.2),
        .init(timeAsSeconds: 6 * 3600 + 1800, value: 0.6),
        .init(timeAsSeconds: 14 * 3600 + 1800, value: 0.65),
        .init(timeAsSeconds: 16 * 3600 + 1800, value: 0.5),
        .init(timeAsSeconds: 20 * 3600 + 1800, value: 0.25),
    ]

    private func withSchedule(_ body: (ProfileManager) -> Void) {
        let manager = ProfileManager.shared
        let savedSchedule = manager.basalSchedule
        let savedTimeZone = manager.timezone
        defer {
            manager.basalSchedule = savedSchedule
            manager.timezone = savedTimeZone
        }
        manager.basalSchedule = schedule
        manager.timezone = TimeZone(secondsFromGMT: 3 * 3600)!
        body(manager)
    }

    private func utc(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }

    @Test("splits at a schedule entry between start and end")
    func splitsAtScheduleEntry() {
        withSchedule { manager in
            let segments = manager.scheduledBasalSegments(from: utc("2026-10-28T13:27:55Z"), to: utc("2026-10-28T13:48:00Z"))
            #expect(segments.map(\.rate) == [0.65, 0.5])
            #expect(segments.map(\.start) == [utc("2026-10-28T13:27:55Z"), utc("2026-10-28T13:30:00Z")])
            #expect(manager.basalRate(at: utc("2026-10-28T13:38:00Z")) == 0.5)
        }
    }

    @Test("splits at midnight in the profile time zone")
    func splitsAtMidnight() {
        withSchedule { manager in
            let segments = manager.scheduledBasalSegments(from: utc("2026-10-28T20:58:00Z"), to: utc("2026-10-28T21:10:00Z"))
            #expect(segments.map(\.rate) == [0.25, 0.2])
            #expect(segments.map(\.start) == [utc("2026-10-28T20:58:00Z"), utc("2026-10-28T21:00:00Z")])
        }
    }

    @Test("splits at the schedule's clock time on a daylight saving change day")
    func splitsAtClockTimeAcrossDST() {
        withSchedule { manager in
            manager.timezone = TimeZone(identifier: "Europe/Stockholm")!
            // 2026-10-25 falls back from UTC+2 to UTC+1 at 03:00, so 16:30 local is 15:30Z
            let segments = manager.scheduledBasalSegments(from: utc("2026-10-25T15:00:00Z"), to: utc("2026-10-25T16:00:00Z"))
            #expect(segments.map(\.rate) == [0.65, 0.5])
            #expect(segments.map(\.start) == [utc("2026-10-25T15:00:00Z"), utc("2026-10-25T15:30:00Z")])
        }
    }

    @Test("skips entries that keep the same rate")
    func skipsUnchangedRate() {
        withSchedule { manager in
            let segments = manager.scheduledBasalSegments(from: utc("2026-10-28T00:00:00Z"), to: utc("2026-10-28T02:00:00Z"))
            #expect(segments.map(\.rate) == [0.2])
        }
    }
}
