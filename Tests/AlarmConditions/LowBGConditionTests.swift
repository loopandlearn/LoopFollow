// LoopFollow
// LowBGConditionTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct LowBGConditionTests {
    let cond = LowBGCondition()

    /// Builds a forward prediction series at 5-minute spacing.
    private func pred(_ values: [Int], from start: Date = Date()) -> [GlucoseValue] {
        values.enumerated().map { i, v in
            GlucoseValue(sgv: v, date: start.addingTimeInterval(Double(i) * 300))
        }
    }

    /// Builds a recent BG history (oldest .. newest) at 5-minute spacing ending now.
    private func history(_ values: [Int], endingAt now: Date = Date()) -> [GlucoseValue] {
        values.enumerated().map { i, v in
            let offset = Double(values.count - 1 - i) * 300
            return GlucoseValue(sgv: v, date: now.addingTimeInterval(-offset))
        }
    }

    /// Recent readings that are clearly above any low threshold. Used by the
    /// predictive tests so the persistence branch evaluates to `false` and the
    /// result reflects the predictive look-ahead alone.
    private var recentHigh: [GlucoseValue] { history([120, 120, 120]) }

    // MARK: - Loop (single forecast)

    @Test("#loop — predictive low within window fires")
    func loopPredictiveLowFires() {
        let alarm = Alarm.low(belowBG: 80, predictiveMinutes: 30, persistentMinutes: 15)
        // ceil(30/5) = 6 points looked at; index 5 dips to 75
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: pred([120, 110, 100, 90, 85, 75]))

        #expect(cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#loop — forecast low beyond window does not fire")
    func loopPredictiveLowBeyondWindow() {
        let alarm = Alarm.low(belowBG: 80, predictiveMinutes: 15, persistentMinutes: 15)
        // ceil(15/5) = 3 points looked at (120, 110, 100); the low only appears later
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: pred([120, 110, 100, 90, 85, 75]))

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#loop — forecast staying above threshold does not fire")
    func loopForecastAboveThreshold() {
        let alarm = Alarm.low(belowBG: 80, predictiveMinutes: 60, persistentMinutes: 15)
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: pred([120, 110, 100, 95, 90, 85]))

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#loop — predictiveMinutes 0 disables look-ahead")
    func loopPredictiveDisabled() {
        let alarm = Alarm.low(belowBG: 80, predictiveMinutes: 0, persistentMinutes: 15)
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: pred([60, 60, 60]))

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    // MARK: - Trio (lowest of four forecasts)

    @Test("#trio — combined forecast fires when one forecast dips low")
    func trioCombinedForecastFires() {
        let alarm = Alarm.low(belowBG: 80, predictiveMinutes: 30, persistentMinutes: 15)
        // ZT stays high, but the IOB forecast dips to 70 — the per-point minimum
        // must surface that dip so the alarm fires.
        let forecasts: [[Double]] = [
            [150, 150, 150, 150, 150, 150], // ZT
            [120, 110, 100, 90, 80, 70], // IOB
            [130, 125, 120, 118, 116, 115], // COB
            [140, 138, 136, 134, 132, 130], // UAM
        ]
        let combined = MainViewController.lowestForecast(forecasts: forecasts, start: Date().timeIntervalSince1970)
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: combined)

        #expect(cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#trio — combined forecast does not fire when all forecasts stay high")
    func trioCombinedForecastNoFire() {
        let alarm = Alarm.low(belowBG: 80, predictiveMinutes: 60, persistentMinutes: 15)
        let forecasts: [[Double]] = [
            [150, 150, 150, 150, 150, 150],
            [120, 110, 100, 95, 92, 90],
            [130, 125, 120, 118, 116, 115],
            [140, 138, 136, 134, 132, 130],
        ]
        let combined = MainViewController.lowestForecast(forecasts: forecasts, start: Date().timeIntervalSince1970)
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: combined)

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#trio — deep forecast below display floor still fires (not masked)")
    func trioDeepLowNotMasked() {
        let alarm = Alarm.low(belowBG: 70, predictiveMinutes: 30, persistentMinutes: 15)
        // A forecast dipping to 30 (below the 39 display floor) is passed through
        // raw, so the predictive-low alarm still fires on a genuine deep low.
        let forecasts: [[Double]] = [
            [150, 150, 150, 150],
            [120, 100, 60, 30],
        ]
        let combined = MainViewController.lowestForecast(forecasts: forecasts, start: Date().timeIntervalSince1970)
        let data = AlarmData.withGlucose(readings: recentHigh, prediction: combined)

        #expect(cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    // MARK: - Persistent / immediate low (device-agnostic)

    @Test("#persistent — all readings in window low fires")
    func persistentLowFires() {
        let alarm = Alarm.low(belowBG: 80, persistentMinutes: 15) // window = 3 readings
        let data = AlarmData.withGlucose(readings: history([75, 72, 70]))

        #expect(cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#persistent — one reading above threshold does not fire")
    func persistentLowOneAbove() {
        let alarm = Alarm.low(belowBG: 80, persistentMinutes: 15)
        let data = AlarmData.withGlucose(readings: history([75, 95, 70]))

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#persistent — not enough samples does not fire")
    func persistentNotEnoughSamples() {
        let alarm = Alarm.low(belowBG: 80, persistentMinutes: 15) // needs 3
        let data = AlarmData.withGlucose(readings: history([70, 70]))

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }

    @Test("#no belowBG threshold never fires")
    func noThresholdNoFire() {
        let alarm = Alarm.low(belowBG: nil, predictiveMinutes: 30, persistentMinutes: 15)
        let data = AlarmData.withGlucose(readings: history([40, 40, 40]), prediction: pred([40, 40, 40]))

        #expect(!cond.evaluate(alarm: alarm, data: data, now: Date()))
    }
}
