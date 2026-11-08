// LoopFollow
// OverrideDetailsTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct OverrideDetailsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(
        percent: Int? = nil,
        low: Double? = nil,
        high: Double? = nil,
        endsIn seconds: TimeInterval? = nil
    ) -> GlucoseSnapshot {
        GlucoseSnapshot(
            glucose: 120,
            delta: 0,
            trend: .flat,
            updatedAt: now,
            iob: nil,
            cob: nil,
            projected: nil,
            override: "Exercise",
            overrideEndAt: seconds.map { now.timeIntervalSince1970 + $0 },
            overridePercent: percent,
            overrideRangeLowMgdl: low,
            overrideRangeHighMgdl: high,
            unit: .mgdl,
            isNotLooping: false
        )
    }

    @Test("Percentage, range and end time, in that order")
    func allDetails() {
        let details = snapshot(percent: 80, low: 140, high: 160, endsIn: 80 * 60).overrideDetails(now: now)
        let end = now.addingTimeInterval(80 * 60)
        #expect(details == ["80%", "140–160", GlucoseSnapshot.clock(end, now: now)])
    }

    @Test("A single-value range shows once")
    func singleValueRange() {
        #expect(snapshot(low: 150, high: 150).overrideDetails(now: now) == ["150"])
    }

    @Test("Unknown parts and indefinite overrides are left out")
    func missingParts() {
        #expect(snapshot().overrideDetails(now: now).isEmpty)
        #expect(snapshot(endsIn: -60).overrideDetails(now: now).isEmpty)
    }

    @Test("The end is a clock time, with the weekday when it is on another day")
    func endTime() {
        let tomorrow = now.addingTimeInterval(86400)
        #expect(snapshot(endsIn: 86400).overrideDetails(now: now) == [GlucoseSnapshot.clock(tomorrow, now: now)])
        #expect(GlucoseSnapshot.clock(tomorrow, now: now) == tomorrow.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
    }

    @Test("A Nightscout range is read in mg/dL, and an unset one is ignored")
    func nightscoutRange() {
        let mgdl = MainViewController.overrideRangeMgdl([140, 160])
        #expect(mgdl?.low == 140)
        #expect(mgdl?.high == 160)
        #expect(MainViewController.overrideRangeMgdl([0, 0]) == nil)
        #expect(MainViewController.overrideRangeMgdl([]) == nil)
    }

    @Test("Values only possible in mmol/L are converted to mg/dL")
    func mmolRange() {
        let range = MainViewController.overrideRangeMgdl([7, 8])
        #expect(range.map { abs($0.low - 7 * GlucoseConversion.mmolToMgDl) < 0.001 } == true)
    }
}
