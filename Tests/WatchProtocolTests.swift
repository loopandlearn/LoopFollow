// LoopFollow
// WatchProtocolTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct WatchProtocolTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func state(alarm: WatchAlarm? = nil) -> WatchState {
        WatchState(
            builtAt: t0,
            snapshot: GlucoseSnapshot(glucose: 142, delta: -3, trend: .downSlight, updatedAt: t0, iob: 1.2, cob: 15, projected: 120, unit: .mmol, isNotLooping: false),
            readings: [WatchReading(t: t0.timeIntervalSince1970 - 300, v: 145), WatchReading(t: t0.timeIntervalSince1970, v: 142)],
            predictions: [WatchPredictionLine(kind: .iob, points: [WatchReading(t: t0.timeIntervalSince1970 + 300, v: 138)])],
            cone: [WatchConePoint(t: t0.timeIntervalSince1970 + 300, low: 120, high: 150)],
            boluses: [WatchReading(t: t0.timeIntervalSince1970 - 600, v: 2.5)],
            carbs: [WatchReading(t: t0.timeIntervalSince1970 - 600, v: 30)],
            lowMgdl: 70,
            highMgdl: 180,
            colorBGText: true,
            lastLoopAt: t0,
            device: "Trio",
            alarm: alarm,
            remote: WatchRemoteConfig(
                kind: .trio,
                maxBolus: 5,
                bolusIncrement: 0.05,
                maxCarbs: 80,
                maxFat: 30,
                maxProtein: 30,
                mealWithBolus: true,
                mealWithFatProtein: false,
                recommendedBolus: 0.4,
                recommendedBolusAt: t0,
                overridePresets: [WatchPreset(id: "Exercise", name: "Exercise", detail: "80 %, 1 h")],
                tempTargetPresets: []
            )
        )
    }

    @Test("State survives the round trip through the application context")
    func stateRoundTrip() throws {
        let original = state(alarm: WatchAlarm(id: UUID(), name: "Low"))
        let data = try #require(original.encoded())
        #expect(WatchState.decode(data) == original)
    }

    @Test("Commands keep their action, id and creation time")
    func commandRoundTrip() throws {
        let actions: [WatchCommand.Action] = [
            .bolus(units: 1.25),
            .meal(carbs: 30, fat: 10, protein: 5, bolus: 2, consumedAt: t0),
            .startOverride(presetID: "Exercise"),
            .cancelOverride,
            .startTempTarget(presetID: UUID().uuidString),
            .cancelTempTarget,
            .snoozeAlarm,
        ]
        for action in actions {
            let command = WatchCommand(action: action)
            let decoded = try JSONDecoder().decode(WatchCommand.self, from: JSONEncoder().encode(command))
            #expect(decoded == command)
        }
    }

    @Test("Glucose and delta follow the phone's unit formatting")
    func glucoseFormatting() {
        #expect(WatchFormat.glucose(142, unit: .mgdl) == "142")
        #expect(WatchFormat.delta(-3, unit: .mgdl) == "-3")
        #expect(WatchFormat.delta(4, unit: .mgdl) == "+4")
        #expect(WatchFormat.delta(0.4, unit: .mgdl) == "0")
        let oneMmol = WatchFormat.delta(GlucoseConversion.mmolToMgDl, unit: .mmol)
        #expect(oneMmol.hasPrefix("+1") && oneMmol.count == 4)
        #expect(!WatchFormat.delta(0.5, unit: .mmol).hasPrefix("+"))
    }

    @Test("Range colors match the phone: red at or below low, yellow at or above high")
    func rangeColors() {
        #expect(WatchFormat.bgColor(70, lowMgdl: 70, highMgdl: 180) == .red)
        #expect(WatchFormat.bgColor(71, lowMgdl: 70, highMgdl: 180) == .green)
        #expect(WatchFormat.bgColor(180, lowMgdl: 70, highMgdl: 180) == .yellow)
        #expect(WatchFormat.bgColor(250, lowMgdl: 70, highMgdl: 180, colored: false) == .primary)
    }
}
