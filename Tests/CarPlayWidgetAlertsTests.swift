// LoopFollow
// CarPlayWidgetAlertsTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct CarPlayWidgetAlertsTests {
    // MARK: - The CarPlay toggle on alarms

    @Test("New alarms are not shown in CarPlay")
    func offByDefault() {
        for type in AlarmType.allCases {
            #expect(Alarm(type: type).showInCarPlay == false)
        }
    }

    @Test("Alarms saved before the toggle existed decode with it off")
    func decodesOldAlarms() throws {
        let data = try JSONEncoder().encode(Alarm(type: .low))
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "showInCarPlay")
        let old = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(Alarm.self, from: old).showInCarPlay == false)
    }

    @Test("The toggle survives saving and loading")
    func roundTrip() throws {
        var alarm = Alarm(type: .notLooping)
        alarm.showInCarPlay = true
        let decoded = try JSONDecoder().decode(Alarm.self, from: JSONEncoder().encode(alarm))
        #expect(decoded.showInCarPlay)
    }

    // MARK: - Which alarms can be checked again

    @Test("Alarms that record that they fired are never checked a second time")
    func oneTimeAlarms() {
        let oneTime: Set<AlarmType> = [
            .cob, .recBolus, .missedBolus, .futureCarbs,
            .overrideStart, .overrideEnd, .tempTargetStart, .tempTargetEnd,
        ]
        for type in AlarmType.allCases {
            #expect(type.isStateCondition == !oneTime.contains(type), "\(type)")
        }
    }

    // MARK: - Wording

    @Test("Glucose alarms show the reading in the user's unit")
    func glucoseDetail() {
        let data = AlarmData.withReadings([90, 75, 63])
        #expect(CarPlayAlert.detail(for: Alarm(type: .low), data: data, unit: .mgdl) == "63 mg/dL")
        #expect(CarPlayAlert.detail(for: Alarm(type: .low), data: data, unit: .mmol) == "3.5 mmol/L")
    }

    @Test("Sensor expiry uses the alarm's sensor lifetime")
    func sensorDetail() {
        let inserted = Date().addingTimeInterval(-9 * 86400)
        let data = AlarmData.withSensorInsertTime(inserted.timeIntervalSince1970)
        let alarm = Alarm.sensorChange(threshold: 12, lifetimeDays: 10)
        let expiry = inserted.addingTimeInterval(10 * 86400)
        #expect(CarPlayAlert.detail(for: alarm, data: data, unit: .mgdl) == "Expires \(GlucoseSnapshot.clock(expiry))")
    }

    @Test("A triggered alarm keeps its id and the title it fired with")
    func alertFromAlarm() {
        var alarm = Alarm(type: .battery)
        alarm.name = "Loop phone"
        let alert = CarPlayAlert(alarm: alarm, title: alarm.name, data: .withBattery(14.6), unit: .mgdl)
        #expect(alert.id == alarm.id)
        #expect(alert.title == "Loop phone")
        #expect(alert.detail == "15%")
        #expect(alert.symbol == AlarmType.battery.icon)
        #expect(alert.isUrgent == false)
        #expect(CarPlayAlert.isUrgent(.low))
    }

    // MARK: - Carbs and recommended bolus

    @Test("Carbs on board over the threshold stay listed after the alarm has announced them")
    func cobHolds() {
        var alarm = Alarm(type: .cob)
        alarm.threshold = 15
        #expect(COBCondition().holds(alarm: alarm, data: .withCOB(21), now: Date()) == true)
        #expect(COBCondition().holds(alarm: alarm, data: .withCOB(10), now: Date()) == false)
        #expect(COBCondition().holds(alarm: alarm, data: .withCOB(nil), now: Date()) == false)
    }

    @Test("A recommended bolus over the threshold stays listed")
    func recBolusHolds() {
        var alarm = Alarm(type: .recBolus)
        alarm.threshold = 1
        #expect(RecBolusCondition().holds(alarm: alarm, data: .withRecBolus(1.4), now: Date()) == true)
        #expect(RecBolusCondition().holds(alarm: alarm, data: .withRecBolus(0.6), now: Date()) == false)
    }

    @Test("Event alarms have no state to check, so they are listed for a while after firing")
    func eventsHaveNoState() {
        let data = AlarmData.withBattery(nil)
        #expect(OverrideStartCondition().holds(alarm: Alarm(type: .overrideStart), data: data, now: Date()) == nil)
        #expect(MissedBolusCondition().holds(alarm: .missedBolus(), data: data, now: Date()) == nil)
        #expect(AlarmManager.carPlayEventDuration == 15 * 60)
    }

    // MARK: - Override line

    @Test("An override with its own range and an end shows percentage, range and end time")
    func overrideWithRangeAndEnd() {
        let now = Date()
        let end = now.addingTimeInterval(46 * 60)
        let snapshot = Self.snapshot(percent: 80, low: 90, high: 100, end: end.timeIntervalSince1970)
        #expect(snapshot.carPlayOverrideDetails(now: now) == ["80%", "90–100", GlucoseSnapshot.clock(end, now: now)])
    }

    @Test("Without its own range or an end, the override shows the loop's target and ∞")
    func overrideFallbacks() {
        let snapshot = Self.snapshot(percent: nil, low: nil, high: nil, end: nil)
        #expect(snapshot.carPlayOverrideDetails() == ["100%", "100–110", "∞"])
        #expect(snapshot.hasActiveOverride(at: Date()))
    }

    @Test("An override whose end has passed is not shown")
    func overrideEnded() {
        let snapshot = Self.snapshot(percent: 80, low: nil, high: nil, end: Date().timeIntervalSince1970 - 60)
        #expect(snapshot.hasActiveOverride(at: Date()) == false)
    }

    @Test("Times read as a clock: the time alone today, with the weekday on another day")
    func clockTimes() throws {
        let now = Date()
        let earlier = try #require(Calendar.current.date(byAdding: .day, value: -2, to: now))
        #expect(GlucoseSnapshot.clock(now, now: now) == now.formatted(date: .omitted, time: .shortened))
        #expect(GlucoseSnapshot.clock(earlier, now: now) == earlier.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
    }

    // MARK: - Widget push

    @Test("Push tokens are written as lowercase hex with leading zeros")
    func pushTokenHex() {
        #expect(CarPlayWidgetStore.hex(Data([0x00, 0x0F, 0xAB, 0xFF])) == "000fabff")
    }

    // MARK: - Pages

    @Test("With alerts the button goes Now, Alerts, 3 h and back to Now")
    func pageCycleWithAlerts() {
        #expect(CarPlayWidgetPage.now.next(hasAlerts: true) == .alerts)
        #expect(CarPlayWidgetPage.alerts.next(hasAlerts: true) == .trend)
        #expect(CarPlayWidgetPage.trend.next(hasAlerts: true) == .now)
    }

    @Test("Without alerts the Alerts page is skipped")
    func pageCycleWithoutAlerts() {
        #expect(CarPlayWidgetPage.now.next(hasAlerts: false) == .trend)
        #expect(CarPlayWidgetPage.trend.next(hasAlerts: false) == .now)
    }

    @Test("An Alerts page whose alerts have cleared shows Now, and its button moves on to 3 h")
    func clearedAlertsPage() {
        #expect(CarPlayWidgetPage.alerts.resolved(hasAlerts: false) == .now)
        #expect(CarPlayWidgetPage.alerts.resolved(hasAlerts: true) == .alerts)
        #expect(CarPlayWidgetPage.alerts.next(hasAlerts: false) == .trend)
    }

    private static func snapshot(percent: Int?, low: Double?, high: Double?, end: TimeInterval?) -> GlucoseSnapshot {
        GlucoseSnapshot(
            glucose: 94, delta: -5, trend: .flat, updatedAt: Date(),
            iob: nil, cob: nil, projected: nil,
            override: "Ajustement", overrideEndAt: end, overridePercent: percent,
            overrideRangeLowMgdl: low, overrideRangeHighMgdl: high,
            targetLowMgdl: 100, targetHighMgdl: 110,
            unit: .mgdl, isNotLooping: false
        )
    }
}

private extension AlarmData {
    static func withCOB(_ cob: Double?) -> Self {
        with(cob: cob, recBolus: nil)
    }

    static func withRecBolus(_ units: Double?) -> Self {
        with(cob: nil, recBolus: units)
    }

    static func with(cob: Double?, recBolus: Double?) -> Self {
        AlarmData(
            bgReadings: [],
            predictionData: [],
            expireDate: nil,
            lastLoopTime: nil,
            latestOverrideStart: nil,
            latestOverrideEnd: nil,
            latestTempTargetStart: nil,
            latestTempTargetEnd: nil,
            recBolus: recBolus,
            COB: cob,
            sageInsertTime: nil,
            pumpInsertTime: nil,
            latestPumpVolume: nil,
            IOB: nil,
            recentBoluses: [],
            latestBattery: nil,
            latestBatteryIsCharging: nil,
            latestPumpBattery: nil,
            batteryHistory: [],
            recentCarbs: [],
            dbSizePercentage: nil
        )
    }
}
