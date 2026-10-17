// LoopFollow
// StatusReadoutTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct StatusReadoutTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func snapshot(
        glucose: Double = 115,
        delta: Double = 5,
        trend: GlucoseSnapshot.Trend = .upSlight,
        ageMinutes: Double = 3,
        iob: Double? = 1.25,
        cob: Double? = 15,
        projected: Double? = nil,
        override: String? = nil,
        overrideEndAt: TimeInterval? = nil,
        tempTargetMgdl: Double? = nil,
        tempTargetEndAt: TimeInterval? = nil,
        recBolus: Double? = nil,
        battery: Double? = nil,
        pumpBattery: Double? = nil,
        basalRate: String = "",
        pumpReservoirU: Double? = nil,
        tdd: Double? = nil,
        carbsToday: Double? = nil,
        profileName: String? = nil,
        sageInsertTime: TimeInterval = 0,
        unit: GlucoseSnapshot.Unit = .mgdl
    ) -> GlucoseSnapshot {
        GlucoseSnapshot(
            glucose: glucose,
            delta: delta,
            trend: trend,
            updatedAt: now.addingTimeInterval(-ageMinutes * 60),
            iob: iob,
            cob: cob,
            projected: projected,
            override: override,
            overrideEndAt: overrideEndAt,
            tempTargetMgdl: tempTargetMgdl,
            tempTargetEndAt: tempTargetEndAt,
            recBolus: recBolus,
            battery: battery,
            pumpBattery: pumpBattery,
            basalRate: basalRate,
            pumpReservoirU: pumpReservoirU,
            tdd: tdd,
            carbsToday: carbsToday,
            profileName: profileName,
            sageInsertTime: sageInsertTime,
            unit: unit,
            isNotLooping: false
        )
    }

    private func input(
        _ snapshot: GlucoseSnapshot?,
        lastLoopMinutesAgo: Double? = 4,
        loopAppName: String = "Loop",
        hasNightscout: Bool = true,
        alarms: AlarmStateInput = AlarmStateInput()
    ) -> StatusReadoutInput {
        StatusReadoutInput(
            snapshot: snapshot,
            lastLoopTime: lastLoopMinutesAgo.map { now.timeIntervalSince1970 - $0 * 60 } ?? 0,
            loopAppName: loopAppName,
            hasNightscout: hasNightscout,
            alarms: alarms,
            now: now
        )
    }

    // MARK: - Glucose line

    @Test("mg/dL glucose line with trend, delta and age")
    func glucoseLineMgdl() {
        let line = StatusReadoutFormatter.glucoseLine(input(snapshot()))
        #expect(line == "Glucose is 115, rising slowly, up 5, 3 minutes ago.")
    }

    @Test("mmol/L uses one decimal and converts the delta")
    func glucoseLineMmol() {
        let line = StatusReadoutFormatter.glucoseLine(input(snapshot(glucose: 115, delta: -9, trend: .down, unit: .mmol)))
        #expect(line == "Glucose is 6.4, falling, down 0.5, 3 minutes ago.")
    }

    @Test("small deltas and unknown trends are omitted")
    func stableGlucose() {
        let line = StatusReadoutFormatter.glucoseLine(input(snapshot(delta: 2, trend: .unknown)))
        #expect(line == "Glucose is 115, 3 minutes ago.")
    }

    @Test("every trend has words")
    func trendWords() {
        let expected: [GlucoseSnapshot.Trend: String?] = [
            .upFast: "rising fast", .up: "rising", .upSlight: "rising slowly", .flat: "steady",
            .downSlight: "falling slowly", .down: "falling", .downFast: "falling fast", .unknown: nil,
        ]
        for (trend, words) in expected {
            #expect(StatusReadoutFormatter.trendWords(trend) == words)
        }
    }

    @Test("stale readings lead with their age")
    func staleReading() {
        let line = StatusReadoutFormatter.glucoseLine(input(snapshot(ageMinutes: 25)))
        #expect(line == "The latest reading is 25 minutes old. It was 115, rising slowly, up 5.")
    }

    @Test("display bounds are spoken as low and high")
    func lowHigh() {
        #expect(StatusReadoutFormatter.glucoseLine(input(snapshot(glucose: 39, delta: 0, trend: .flat))) == "Glucose is low, steady, 3 minutes ago.")
        #expect(StatusReadoutFormatter.glucoseLine(input(snapshot(glucose: 401, delta: 0, trend: .flat))) == "Glucose is high, steady, 3 minutes ago.")
    }

    @Test("display value rounds like the screen")
    func displayValue() {
        #expect(StatusReadoutFormatter.displayValue(115.4, unit: .mgdl) == 115)
        #expect(StatusReadoutFormatter.displayValue(115, unit: .mmol) == 6.4)
    }

    // MARK: - Full readout

    @Test("full readout for a Nightscout follower")
    func fullReadout() {
        let text = StatusReadoutFormatter.fullReadout(input(snapshot()))
        #expect(text == "Glucose is 115, rising slowly, up 5, 3 minutes ago. IOB is 1.25 units. COB is 15 grams. The loop last completed 4 minutes ago.")
    }

    @Test("not looping is recomputed from the loop time")
    func notLooping() {
        let text = StatusReadoutFormatter.fullReadout(input(snapshot(iob: nil, cob: nil), lastLoopMinutesAgo: 22))
        #expect(text == "Glucose is 115, rising slowly, up 5, 3 minutes ago. The loop hasn't completed in 22 minutes.")
    }

    @Test("Dexcom-only followers hear only the glucose line")
    func dexcomOnly() {
        let text = StatusReadoutFormatter.fullReadout(input(snapshot(), hasNightscout: false))
        #expect(text == "Glucose is 115, rising slowly, up 5, 3 minutes ago.")
    }

    @Test("no data fallback")
    func noData() {
        #expect(StatusReadoutFormatter.fullReadout(input(nil)) == StatusReadoutFormatter.noDataText)
        #expect(StatusReadoutFormatter.glucoseLine(input(nil)) == nil)
    }

    @Test("active override and temp target are included with remaining time")
    func overrideAndTempTarget() {
        let snap = snapshot(
            iob: nil, cob: nil,
            override: "Exercise",
            overrideEndAt: now.timeIntervalSince1970 + 42 * 60,
            tempTargetMgdl: 140,
            tempTargetEndAt: now.timeIntervalSince1970 + 30 * 60
        )
        let text = StatusReadoutFormatter.fullReadout(input(snap, lastLoopMinutesAgo: nil))
        #expect(text == "Glucose is 115, rising slowly, up 5, 3 minutes ago. Override Exercise is active for another 42 minutes. A temp target of 140 is active for another 30 minutes.")
    }

    @Test("indefinite override has no countdown; an expired one is omitted")
    func overrideEnds() {
        #expect(StatusReadoutFormatter.overrideSentence(input(snapshot(override: "Sleep"))) == "Override Sleep is active.")
        let expired = snapshot(override: "Sleep", overrideEndAt: now.timeIntervalSince1970 - 60)
        #expect(StatusReadoutFormatter.overrideSentence(input(expired)) == nil)
        #expect(StatusReadoutFormatter.text(for: .override, input(expired)) == "No override is active.")
    }

    // MARK: - Single fields

    @Test("delta field speaks small changes too")
    func deltaField() {
        #expect(StatusReadoutFormatter.text(for: .delta, input(snapshot(delta: 2))) == "Glucose is up 2 since the previous reading.")
        #expect(StatusReadoutFormatter.text(for: .delta, input(snapshot(delta: 0))) == "Glucose is unchanged since the previous reading.")
    }

    @Test("missing values say so")
    func missingValues() {
        let snap = snapshot(iob: nil, cob: nil)
        #expect(StatusReadoutFormatter.text(for: .iob, input(snap)) == "IOB is not available.")
        #expect(StatusReadoutFormatter.text(for: .cob, input(snap)) == "COB is not available.")
        #expect(StatusReadoutFormatter.text(for: .pumpReservoir, input(snap)) == "The pump reservoir is above 50 units or not reported.")
        #expect(StatusReadoutFormatter.text(for: .sensorAge, input(snap)) == "Sensor age is not set.")
        #expect(StatusReadoutFormatter.text(for: .recommendedBolus, input(snap)) == "No recommended bolus is reported.")
        #expect(StatusReadoutFormatter.text(for: .lastLoop, input(snap, lastLoopMinutesAgo: nil)) == "No loop data is available.")
        #expect(StatusReadoutFormatter.text(for: .iob, input(nil)) == StatusReadoutFormatter.noDataText)
    }

    @Test("pump, battery, age, profile and totals")
    func pumpFields() {
        let snap = snapshot(
            projected: 125,
            recBolus: 0.8,
            battery: 81.4,
            pumpBattery: 50,
            pumpReservoirU: 85.6,
            tdd: 32.46,
            carbsToday: 120,
            profileName: "Default",
            sageInsertTime: now.timeIntervalSince1970 - (3 * 86400 + 4 * 3600)
        )
        let i = input(snap)
        #expect(StatusReadoutFormatter.text(for: .predictedGlucose, i) == "The predicted glucose is 125.")
        #expect(StatusReadoutFormatter.text(for: .pumpReservoir, i) == "The pump reservoir has 86 units.")
        #expect(StatusReadoutFormatter.text(for: .pumpBattery, i) == "The pump battery is at 50 percent.")
        #expect(StatusReadoutFormatter.text(for: .phoneBattery, i) == "The looping phone battery is at 81 percent.")
        #expect(StatusReadoutFormatter.text(for: .sensorAge, i) == "Sensor age is 3 days, 4 hours.")
        #expect(StatusReadoutFormatter.text(for: .profile, i) == "The active profile is Default.")
        #expect(StatusReadoutFormatter.text(for: .carbsToday, i) == "120 grams of carbs have been entered today.")
        #expect(StatusReadoutFormatter.text(for: .totalDailyDose, i) == "The total daily dose is 32.5 units.")
        #expect(StatusReadoutFormatter.text(for: .recommendedBolus, i) == "Loop reports a recommended bolus of 0.8 units. The reading is 3 minutes old.")
    }

    @Test("basal strings in both stored forms")
    func basal() {
        let en = Locale(identifier: "en_US")
        #expect(StatusReadoutFormatter.basalSentence("0.8", locale: en) == "The basal rate is 0.8 units per hour.")
        #expect(StatusReadoutFormatter.basalSentence("0.8 → 1.2", locale: en) == "The basal rate is 1.2 units per hour, temporarily changed from 0.8.")
        #expect(StatusReadoutFormatter.basalSentence("0,8 → 1,25", locale: Locale(identifier: "sv_SE")) == "The basal rate is 1.25 units per hour, temporarily changed from 0.8.")
        #expect(StatusReadoutFormatter.basalSentence("", locale: en) == nil)
    }

    // MARK: - Alarms

    @Test("alarm state sentences")
    func alarms() {
        let none = StatusReadoutFormatter.alarmSentence(input(nil))
        #expect(none == "No alarms are snoozed.")

        let sounding = StatusReadoutFormatter.alarmSentence(input(nil, alarms: AlarmStateInput(soundingAlarmName: "Low BG Alert")))
        #expect(sounding == "No alarms are snoozed. Low BG Alert is sounding.")

        let snoozed = StatusReadoutFormatter.alarmSentence(input(nil, alarms: AlarmStateInput(snoozeUntil: now.addingTimeInterval(3600))))
        #expect(snoozed.hasPrefix("All alarms are snoozed until "))

        let expired = StatusReadoutFormatter.alarmSentence(input(nil, alarms: AlarmStateInput(snoozeUntil: now.addingTimeInterval(-60), muteUntil: now.addingTimeInterval(600))))
        #expect(expired.hasPrefix("Alarm sounds are muted until "))
        #expect(!expired.contains("snoozed until"))
    }
}
