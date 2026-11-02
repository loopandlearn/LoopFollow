// LoopFollow
// TempTargetEndConditionTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct TempTargetEndConditionTests {
    let cond = TempTargetEndCondition()

    private func reset() {
        Storage.shared.lastTempTargetEndNotified.value = nil
        Storage.shared.lastTempTargetPreEndNotified.value = nil
    }

    // MARK: - End firing

    @Test("end firing fires once, then dedups")
    func endFiresOnceThenDedups() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 - 60
        let alarm = Alarm.tempTargetEnd()
        let data = AlarmData.withEnds(latestTempTargetEnd: end)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("end firing ignores ends older than 15 minutes")
    func endIgnoresStaleEnds() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 - 16 * 60
        let alarm = Alarm.tempTargetEnd()
        let data = AlarmData.withEnds(latestTempTargetEnd: end)

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    // MARK: - Early warning

    @Test("no early warning without a lead time")
    func noEarlyWarningByDefault() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 4 * 60
        let data = AlarmData.withEnds(activeTempTargetEnd: end)

        #expect(!cond.evaluate(alarm: .tempTargetEnd(), data: data, now: now))
        #expect(!cond.evaluate(alarm: .tempTargetEnd(warnBefore: 0), data: data, now: now))
    }

    @Test("early warning fires inside the lead window, once")
    func earlyWarningFiresOnceInsideWindow() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 5 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 10)
        let data = AlarmData.withEnds(activeTempTargetEnd: end)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("early warning does NOT fire before the lead window")
    func earlyWarningWaitsForWindow() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 6 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)
        let data = AlarmData.withEnds(activeTempTargetEnd: end)

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("early warning and end both fire for one event, with the right titles")
    func bothPhasesFireWithTitles() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 4 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)

        let preData = AlarmData.withEnds(activeTempTargetEnd: end)
        #expect(cond.evaluate(alarm: alarm, data: preData, now: now))
        #expect(cond.firedTitle == "Temp Target Ending Soon")

        let endNow = Date(timeIntervalSince1970: end + 60)
        let endData = AlarmData.withEnds(latestTempTargetEnd: end)
        #expect(cond.evaluate(alarm: alarm, data: endData, now: endNow))
        #expect(cond.firedTitle == nil)
    }

    @Test("extending the temp target re-arms the early warning for the new end")
    func extensionRearmsEarlyWarning() {
        reset()
        let now = Date()
        let firstEnd = now.timeIntervalSince1970 + 4 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)

        #expect(cond.evaluate(alarm: alarm, data: .withEnds(activeTempTargetEnd: firstEnd), now: now))

        let extendedEnd = firstEnd + 30 * 60
        let laterNow = Date(timeIntervalSince1970: extendedEnd - 4 * 60)
        #expect(cond.evaluate(alarm: alarm, data: .withEnds(activeTempTargetEnd: extendedEnd), now: laterNow))
    }

    @Test("when both phases are due, the end fires first and the warning follows")
    func endPhaseWinsSameTick() {
        reset()
        let now = Date()
        let previousEnd = now.timeIntervalSince1970 - 60
        let activeEnd = now.timeIntervalSince1970 + 2 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)
        let data = AlarmData.withEnds(latestTempTargetEnd: previousEnd, activeTempTargetEnd: activeEnd)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(cond.firedTitle == nil)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(cond.firedTitle == "Temp Target Ending Soon")

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("a replacement whose end is earlier than a warned end still warns")
    func replacementWithEarlierEndWarns() {
        reset()
        let now = Date()
        let alarm = Alarm.tempTargetEnd(warnBefore: 30)
        let firstEnd = now.timeIntervalSince1970 + 25 * 60
        #expect(cond.evaluate(alarm: alarm, data: .withEnds(activeTempTargetEnd: firstEnd), now: now))

        let replacementEnd = now.timeIntervalSince1970 + 10 * 60
        #expect(cond.evaluate(alarm: alarm, data: .withEnds(activeTempTargetEnd: replacementEnd), now: now))
        #expect(cond.firedTitle == "Temp Target Ending Soon")
    }

    @Test("no early warning when the lead time covers the whole event")
    func noEarlyWarningForEventShorterThanLead() {
        reset()
        let now = Date()
        let alarm = Alarm.tempTargetEnd(warnBefore: 30)
        let start = now.timeIntervalSince1970 - 60
        let end = now.timeIntervalSince1970 + 20 * 60
        let data = AlarmData.withEnds(latestTempTargetStart: start, activeTempTargetEnd: end)

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }
}
