// LoopFollow
// SensorAgeConditionTests.swift

@testable import LoopFollow
import Testing

struct SensorAgeConditionTests {
    let cond = SensorAgeCondition()

    // MARK: - 10-day lifetime (default)

    @Test("fires when within threshold hours of 10-day expiry")
    func firesNear10DayExpiry() {
        let alarm = Alarm.sensorChange(threshold: 12, lifetimeDays: 10)
        // Sensor inserted 9 days and 13 hours ago → 11 hours until 10-day mark → within 12-hour window
        let insertTime = Date().addingTimeInterval(-9 * 86400 - 13 * 3600).timeIntervalSince1970
        let data = AlarmData.withSensorInsertTime(insertTime)
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire when far from 10-day expiry")
    func doesNotFireEarly() {
        let alarm = Alarm.sensorChange(threshold: 12, lifetimeDays: 10)
        // Sensor inserted 8 days ago → 2 days until 10-day mark → outside 12-hour window
        let insertTime = Date().addingTimeInterval(-8 * 86400).timeIntervalSince1970
        let data = AlarmData.withSensorInsertTime(insertTime)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    // MARK: - 15-day lifetime

    @Test("fires when within threshold hours of 15-day expiry")
    func firesNear15DayExpiry() {
        let alarm = Alarm.sensorChange(threshold: 12, lifetimeDays: 15)
        // Sensor inserted 14 days and 13 hours ago → 11 hours until 15-day mark
        let insertTime = Date().addingTimeInterval(-14 * 86400 - 13 * 3600).timeIntervalSince1970
        let data = AlarmData.withSensorInsertTime(insertTime)
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire at day 10 when lifetime is 15 days")
    func doesNotFireAtDay10With15DayLifetime() {
        let alarm = Alarm.sensorChange(threshold: 12, lifetimeDays: 15)
        // Sensor inserted 10 days ago → 5 days until 15-day mark → should NOT fire
        let insertTime = Date().addingTimeInterval(-10 * 86400).timeIntervalSince1970
        let data = AlarmData.withSensorInsertTime(insertTime)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    // MARK: - Edge cases

    @Test("does NOT fire when sageInsertTime is nil")
    func ignoresMissingSensor() {
        let alarm = Alarm.sensorChange(threshold: 12)
        let data = AlarmData.withSensorInsertTime(nil)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire when sageInsertTime is zero (no sensor data)")
    func ignoresZeroInsertTime() {
        let alarm = Alarm.sensorChange(threshold: 12)
        let data = AlarmData.withSensorInsertTime(0)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("does NOT fire when threshold is nil")
    func ignoresNilThreshold() {
        let alarm = Alarm.sensorChange(threshold: nil)
        let insertTime = Date().addingTimeInterval(-11 * 86400).timeIntervalSince1970
        let data = AlarmData.withSensorInsertTime(insertTime)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("defaults to 10-day lifetime when sensorLifetimeDays is nil")
    func defaultsTo10Days() {
        let alarm = Alarm.sensorChange(threshold: 12, lifetimeDays: nil)
        // Sensor inserted 9 days and 13 hours ago → within 12-hour window of 10-day mark
        let insertTime = Date().addingTimeInterval(-9 * 86400 - 13 * 3600).timeIntervalSince1970
        let data = AlarmData.withSensorInsertTime(insertTime)
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }
}
