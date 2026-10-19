// LoopFollow
// WatchRemoteTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct WatchRemoteTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private let limits = WatchCommandValidator.Limits(
        maxBolus: 2,
        bolusIncrement: 0.05,
        maxCarbs: 60,
        maxFat: 30,
        maxProtein: 30,
        mealWithBolus: true,
        mealWithFatProtein: false
    )

    private func validate(_ action: WatchCommand.Action, _ kind: WatchRemoteConfig.Kind, limits: WatchCommandValidator.Limits? = nil) -> Result<WatchCommand.Action, WatchCommandValidator.ValidationError> {
        WatchCommandValidator.validate(action, kind: kind, limits: limits ?? self.limits, now: now)
    }

    // MARK: - Validation

    @Test("Trio boluses round down to the increment and respect the maximum")
    func trioBolus() {
        #expect(validate(.bolus(units: 1.27), .trio) == .success(.bolus(units: 1.25)))
        #expect((try? validate(.bolus(units: 2.5), .trio).get()) == nil)
        #expect((try? validate(.bolus(units: 0.01), .trio).get()) == nil)
    }

    @Test("Loop boluses are sent as entered, up to the maximum")
    func loopBolus() {
        #expect(validate(.bolus(units: 1.27), .loop) == .success(.bolus(units: 1.27)))
        #expect((try? validate(.bolus(units: 2.01), .loop).get()) == nil)
    }

    @Test("Loop meals are carbs only, within the time window Loop accepts")
    func loopMeal() {
        #expect((try? validate(.meal(carbs: 30, fat: 0, protein: 0, bolus: 0, consumedAt: now), .loop).get()) != nil)
        #expect((try? validate(.meal(carbs: 30, fat: 0, protein: 0, bolus: 1, consumedAt: now), .loop).get()) == nil)
        #expect((try? validate(.meal(carbs: 70, fat: 0, protein: 0, bolus: 0, consumedAt: now), .loop).get()) == nil)
        #expect((try? validate(.meal(carbs: 30, fat: 0, protein: 0, bolus: 0, consumedAt: now.addingTimeInterval(-13 * 3600)), .loop).get()) == nil)
        #expect((try? validate(.meal(carbs: 30, fat: 0, protein: 0, bolus: 0, consumedAt: now.addingTimeInterval(2 * 3600)), .loop).get()) == nil)
    }

    @Test("Trio meals follow the phone's Meal settings")
    func trioMeal() {
        #expect((try? validate(.meal(carbs: 30, fat: 10, protein: 0, bolus: 0, consumedAt: now), .trio).get()) == nil)
        #expect(validate(.meal(carbs: 30, fat: 0, protein: 0, bolus: 1.27, consumedAt: now), .trio)
            == .success(.meal(carbs: 30, fat: 0, protein: 0, bolus: 1.25, consumedAt: now)))
        var noBolus = limits
        noBolus.mealWithBolus = false
        #expect((try? validate(.meal(carbs: 30, fat: 0, protein: 0, bolus: 1, consumedAt: now), .trio, limits: noBolus).get()) == nil)
    }

    @Test("Temp targets are refused for Loop")
    func loopTempTarget() {
        #expect((try? validate(.startTempTarget(presetID: "x"), .loop).get()) == nil)
        #expect((try? validate(.startTempTarget(presetID: "x"), .trio).get()) != nil)
    }

    // MARK: - Signing key

    @Test("LoopFollow's own key signs when both apps share a team or no remote team is set")
    func signingKey() {
        let lf = (key: "LF", keyID: "LFKEY")
        let remote = (key: "R", keyID: "RKEY")
        #expect(RemoteSigningKey.resolve(lfTeamID: "T1", remoteTeamID: "T1", lfKey: lf, remoteKey: remote).key == "LF")
        #expect(RemoteSigningKey.resolve(lfTeamID: "T1", remoteTeamID: "", lfKey: lf, remoteKey: remote).key == "LF")
        let other = RemoteSigningKey.resolve(lfTeamID: "T1", remoteTeamID: "T2", lfKey: lf, remoteKey: remote)
        #expect(other.key == "R")
        #expect(other.teamID == "T2")
    }

    // MARK: - Device status

    @Test("Loop devicestatus gives IOB, COB, recommendation and the prediction")
    func loopDeviceStatus() {
        let status: [String: Any] = [
            "loop": [
                "timestamp": "2026-10-19T08:00:00Z",
                "iob": ["iob": 1.2],
                "cob": ["cob": 15.0],
                "recommendedBolus": 0.3,
                "predicted": ["startDate": "2026-10-19T08:00:00Z", "values": [120.0, 125.0, 130.0]],
            ],
        ]
        let summary = DeviceStatusSummary.parse(status, showsCone: false)
        #expect(summary.iob == 1.2)
        #expect(summary.cob == 15)
        #expect(summary.recommendedBolus == 0.3)
        #expect(summary.predictions.first?.kind == .loop)
        #expect(summary.predictions.first?.points.map(\.v) == [120, 125, 130])
        #expect(summary.loopAt == DeviceStatusSummary.date("2026-10-19T08:00:00.000Z"))
    }

    @Test("Trio devicestatus gives lines or the cone, matching what the phone showed")
    func trioDeviceStatus() {
        let status: [String: Any] = [
            "openaps": [
                "iob": ["iob": 1.5],
                "suggested": [
                    "timestamp": "2026-10-19T08:00:00.000Z",
                    "COB": 20.0,
                    "predBGs": ["IOB": [140.0, 138.0], "ZT": [140.0, 130.0], "COB": [140.0, 150.0]],
                ],
            ],
        ]
        let lines = DeviceStatusSummary.parse(status, showsCone: false)
        #expect(lines.iob == 1.5)
        #expect(lines.cob == 20)
        #expect(Set(lines.predictions.map(\.kind)) == [.iob, .zt, .cob])

        let cone = DeviceStatusSummary.parse(status, showsCone: true)
        #expect(cone.predictions.isEmpty)
        #expect(cone.cone.map(\.low) == [139, 130])
        #expect(cone.cone.map(\.high) == [141, 150])
    }

    // MARK: - Loop override payload

    @Test("Loop override payload carries name, duration and return info")
    func loopOverridePayload() {
        let info = ReturnNotificationInfo(productionEnvironment: false, deviceToken: "tok", bundleId: "b", teamId: "t", keyId: "k", apnsKey: "a")
        let payload = LoopAPNSCommands.overridePayload(presetName: "Running", duration: 3600, returnInfo: info, now: now)
        #expect(payload["override-name"] as? String == "Running")
        #expect(payload["override-duration-minutes"] as? Int == 60)
        #expect(payload["alert"] as? String == "Running Temporary Override (1h 0m)")
        #expect((payload["return_notification"] as? [String: Any])?["device_token"] as? String == "tok")

        let cancel = LoopAPNSCommands.cancelOverridePayload(returnInfo: nil, now: now)
        #expect(cancel["cancel-temporary-override"] as? String == "true")
        #expect(cancel["return_notification"] == nil)
    }
}
