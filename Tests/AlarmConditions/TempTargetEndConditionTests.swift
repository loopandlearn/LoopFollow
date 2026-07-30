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
        let data = AlarmData.withTempTargetEnds(latestEnd: end)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("end firing ignores ends older than 15 minutes")
    func endIgnoresStaleEnds() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 - 16 * 60
        let alarm = Alarm.tempTargetEnd()
        let data = AlarmData.withTempTargetEnds(latestEnd: end)

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    // MARK: - Early warning

    @Test("no early warning without a lead time")
    func noEarlyWarningByDefault() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 4 * 60
        let data = AlarmData.withTempTargetEnds(activeEnd: end)

        #expect(!cond.evaluate(alarm: .tempTargetEnd(), data: data, now: now))
        #expect(!cond.evaluate(alarm: .tempTargetEnd(warnBefore: 0), data: data, now: now))
    }

    @Test("early warning fires inside the lead window, once")
    func earlyWarningFiresOnceInsideWindow() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 5 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 10)
        let data = AlarmData.withTempTargetEnds(activeEnd: end)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("early warning does NOT fire before the lead window")
    func earlyWarningWaitsForWindow() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 6 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)
        let data = AlarmData.withTempTargetEnds(activeEnd: end)

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }

    @Test("early warning and end both fire for one event, with the right titles")
    func bothPhasesFireWithTitles() {
        reset()
        let now = Date()
        let end = now.timeIntervalSince1970 + 4 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)

        let preData = AlarmData.withTempTargetEnds(activeEnd: end)
        #expect(cond.evaluate(alarm: alarm, data: preData, now: now))
        #expect(cond.notificationTitle(alarm: alarm, data: preData, now: now) == "Temp Target Ending Soon")

        let endNow = Date(timeIntervalSince1970: end + 60)
        let endData = AlarmData.withTempTargetEnds(latestEnd: end)
        #expect(cond.evaluate(alarm: alarm, data: endData, now: endNow))
        #expect(cond.notificationTitle(alarm: alarm, data: endData, now: endNow) == nil)
    }

    @Test("extending the temp target re-arms the early warning for the new end")
    func extensionRearmsEarlyWarning() {
        reset()
        let now = Date()
        let firstEnd = now.timeIntervalSince1970 + 4 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)

        #expect(cond.evaluate(alarm: alarm, data: .withTempTargetEnds(activeEnd: firstEnd), now: now))

        let extendedEnd = firstEnd + 30 * 60
        let laterNow = Date(timeIntervalSince1970: extendedEnd - 4 * 60)
        #expect(cond.evaluate(alarm: alarm, data: .withTempTargetEnds(activeEnd: extendedEnd), now: laterNow))
    }

    @Test("when both phases are due, the end fires first and the warning follows")
    func endPhaseWinsSameTick() {
        reset()
        let now = Date()
        let previousEnd = now.timeIntervalSince1970 - 60
        let activeEnd = now.timeIntervalSince1970 + 2 * 60
        let alarm = Alarm.tempTargetEnd(warnBefore: 5)
        let data = AlarmData.withTempTargetEnds(latestEnd: previousEnd, activeEnd: activeEnd)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(cond.notificationTitle(alarm: alarm, data: data, now: now) == nil)

        #expect(cond.evaluate(alarm: alarm, data: data, now: now))
        #expect(cond.notificationTitle(alarm: alarm, data: data, now: now) == "Temp Target Ending Soon")

        #expect(!cond.evaluate(alarm: alarm, data: data, now: now))
    }
}
