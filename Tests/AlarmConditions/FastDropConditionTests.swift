// LoopFollow
// FastDropConditionTests.swift

import Foundation
@testable import LoopFollow
import Testing

/// Fast drop fires only when **each** of the last `monitoringWindow` consecutive
/// intervals dropped by at least `delta` mg/dL. It is per-reading, not a single
/// cumulative drop — these tests pin that behaviour down.
struct FastDropConditionTests {
    let cond = FastDropCondition()

    // MARK: - Fires

    @Test("fires when every one of N readings drops by at least delta")
    func firesOnConsecutiveDrops() {
        // 3 intervals, each falling exactly 15 → about 45 over ~15 minutes
        let alarm = Alarm.fastDrop(delta: 15, window: 3)
        let data = AlarmData.withReadings([150, 135, 120, 105])
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("a drop exactly equal to delta still counts")
    func firesAtExactThreshold() {
        let alarm = Alarm.fastDrop(delta: 15, window: 1)
        let data = AlarmData.withReadings([120, 105])
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("only the most recent window+1 readings matter")
    func ignoresOlderReadings() {
        // Earlier readings rise sharply; the last 4 fall 15 each → fires
        let alarm = Alarm.fastDrop(delta: 15, window: 3)
        let data = AlarmData.withReadings([100, 200, 165, 150, 135, 120])
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    // MARK: - Does not fire

    @Test("does NOT fire when one interval falls short of delta")
    func doesNotFireWhenOneIntervalTooSmall() {
        let alarm = Alarm.fastDrop(delta: 15, window: 3)
        // middle interval is only 10
        let data = AlarmData.withReadings([150, 135, 125, 110])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("per-reading, not cumulative: 40+5+5 = 50 total but does NOT fire")
    func doesNotFireOnCumulativeOnly() {
        let alarm = Alarm.fastDrop(delta: 15, window: 3)
        // total fall is 50 (> 45) but two intervals are only 5 each
        let data = AlarmData.withReadings([150, 110, 105, 100])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire when glucose is rising")
    func doesNotFireWhenRising() {
        let alarm = Alarm.fastDrop(delta: 15, window: 3)
        let data = AlarmData.withReadings([100, 115, 130, 145])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire without enough readings")
    func doesNotFireWithTooFewReadings() {
        // window 3 needs 4 readings; only 3 supplied
        let alarm = Alarm.fastDrop(delta: 15, window: 3)
        let data = AlarmData.withReadings([135, 120, 105])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    // MARK: - Guard cases

    @Test("does NOT fire when delta is nil")
    func ignoresNilDelta() {
        let alarm = Alarm.fastDrop(delta: nil, window: 3)
        let data = AlarmData.withReadings([150, 135, 120, 105])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire when window is nil")
    func ignoresNilWindow() {
        let alarm = Alarm.fastDrop(delta: 15, window: nil)
        let data = AlarmData.withReadings([150, 135, 120, 105])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire when window is zero")
    func ignoresZeroWindow() {
        let alarm = Alarm.fastDrop(delta: 15, window: 0)
        let data = AlarmData.withReadings([150, 135, 120, 105])
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }
}
