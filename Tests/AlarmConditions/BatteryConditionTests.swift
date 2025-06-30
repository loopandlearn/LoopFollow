// LoopFollow
// BatteryConditionTests.swift
// Created by Jonas Björkert.

@testable import LoopFollow
import Testing

struct BatteryConditionTests {
    let cond = BatteryCondition()

    @Test("#fires when battery ≤ threshold")
    func firesBelowOrEqual() {
        let alarm = Alarm.battery(threshold: 20)
        let data = AlarmData.withBattery(20)
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("#does NOT fire when battery > threshold")
    func ignoresAbove() {
        let alarm = Alarm.battery(threshold: 20)
        let data = AlarmData.withBattery(55)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("#does NOT fire if no battery reading")
    func ignoresMissingReading() {
        let alarm = Alarm.battery(threshold: 20)
        let data = AlarmData.withBattery(nil)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("#does NOT fire if threshold is nil / zero")
    func ignoresBadConfig() {
        let alarm = Alarm.battery(threshold: nil)
        let data = AlarmData.withBattery(5)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }
}
