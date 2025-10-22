// LoopFollow
// PumpBatteryConditionTests.swift

@testable import LoopFollow
import Testing

struct PumpBatteryConditionTests {
    let cond = PumpBatteryCondition()

    @Test("#fires when pump battery ≤ threshold")
    func firesBelowOrEqual() {
        let alarm = Alarm.pumpBattery(threshold: 25)
        let data = AlarmData.withPumpBattery(20)
        #expect(cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("#does NOT fire when pump battery > threshold")
    func ignoresAbove() {
        let alarm = Alarm.pumpBattery(threshold: 25)
        let data = AlarmData.withPumpBattery(50)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("#does NOT fire if no pump battery reading")
    func ignoresMissingReading() {
        let alarm = Alarm.pumpBattery(threshold: 25)
        let data = AlarmData.withPumpBattery(nil)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }

    @Test("#does NOT fire if threshold is nil / zero")
    func ignoresBadConfig() {
        let alarm = Alarm.pumpBattery(threshold: nil)
        let data = AlarmData.withPumpBattery(5)
        #expect(!cond.evaluate(alarm: alarm, data: data, now: .init()))
    }
}
