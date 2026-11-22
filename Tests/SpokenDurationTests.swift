// LoopFollow
// SpokenDurationTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct SpokenDurationTests {
    @Test("durations are spoken in whole minutes with at most two units")
    func durations() {
        #expect(SpokenDuration.duration(30) == "less than a minute")
        #expect(SpokenDuration.duration(60) == "1 minute")
        #expect(SpokenDuration.duration(5 * 60 + 59) == "5 minutes")
        #expect(SpokenDuration.duration(90 * 60) == "1 hour, 30 minutes")
        #expect(SpokenDuration.duration(2 * 60 * 60) == "2 hours")
        #expect(SpokenDuration.duration(3 * 86400 + 4 * 3600 + 20 * 60) == "3 days, 4 hours")
    }

    @Test("ago phrases")
    func ago() {
        #expect(SpokenDuration.ago(10) == "just now")
        #expect(SpokenDuration.ago(3 * 60) == "3 minutes ago")
    }

    @Test("clock time follows the given locale")
    func clockTime() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC
        let utc = TimeZone(identifier: "UTC")!
        #expect(SpokenDuration.clockTime(date, locale: Locale(identifier: "en_US"), timeZone: utc) == "10:13 PM")
        #expect(SpokenDuration.clockTime(date, locale: Locale(identifier: "sv_SE"), timeZone: utc) == "22:13")
    }
}
