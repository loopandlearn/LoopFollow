// LoopFollow
// MissedBolusConditionTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct MissedBolusConditionTests {
    let cond = MissedBolusCondition()

    private func resetNotified() {
        Storage.shared.lastMissedBolusNotified.value = nil
    }

    private func carb(minutesAgo: Double, grams: Double = 30, relativeTo now: Date) -> CarbSample {
        CarbSample(grams: grams, date: now.addingTimeInterval(-minutesAgo * 60))
    }

    private func bolus(minutesAgo: Double, units: Double, relativeTo now: Date) -> BolusEntry {
        BolusEntry(units: units, date: now.addingTimeInterval(-minutesAgo * 60))
    }

    @Test("#fires — default alarm, carbs past delay with no bolus")
    func firesWithDefaults() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs([carb(minutesAgo: 20, relativeTo: now)])

        #expect(cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }

    @Test("#fires once — same carb entry does not fire twice")
    func firesOncePerCarb() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs([carb(minutesAgo: 20, relativeTo: now)])

        #expect(cond.evaluate(alarm: .missedBolus(), data: data, now: now))
        #expect(!cond.evaluate(alarm: .missedBolus(), data: data, now: now.addingTimeInterval(300)))
    }

    @Test("#within delay — carbs newer than delay do not fire")
    func withinDelayNoFire() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs([carb(minutesAgo: 10, relativeTo: now)])

        #expect(!cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }

    @Test("#bolus given — bolus after carbs suppresses")
    func bolusAfterCarbsNoFire() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs(
            [carb(minutesAgo: 20, relativeTo: now)],
            boluses: [bolus(minutesAgo: 18, units: 2, relativeTo: now)]
        )

        #expect(!cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }

    @Test("#pre-bolus — bolus inside pre-bolus window suppresses")
    func preBolusNoFire() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs(
            [carb(minutesAgo: 20, relativeTo: now)],
            boluses: [bolus(minutesAgo: 30, units: 2, relativeTo: now)]
        )

        #expect(!cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }

    @Test("#small bolus — bolus at or below limit is ignored")
    func smallBolusIgnored() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs(
            [carb(minutesAgo: 20, relativeTo: now)],
            boluses: [bolus(minutesAgo: 18, units: 0.1, relativeTo: now)]
        )

        #expect(cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }

    @Test("#small carbs — carbs at or below limit do not fire")
    func smallCarbsNoFire() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs([carb(minutesAgo: 20, grams: 4, relativeTo: now)])

        #expect(!cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }

    @Test("#future carbs — a future-dated entry does not mask a past one")
    func futureCarbDoesNotMaskPast() {
        resetNotified()
        let now = Date()
        let data = AlarmData.withCarbs([
            carb(minutesAgo: 20, relativeTo: now),
            carb(minutesAgo: -30, relativeTo: now),
        ])

        #expect(cond.evaluate(alarm: .missedBolus(), data: data, now: now))
    }
}
