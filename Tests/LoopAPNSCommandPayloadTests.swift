// LoopFollow
// LoopAPNSCommandPayloadTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct LoopAPNSCommandPayloadTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let headerKeys: Set<String> = ["otp", "remote-address", "notes", "entered-by", "sent-at", "expiration", "alert"]

    @Test("carbs payload carries the loop.js keys")
    func carbsKeys() {
        let payload = LoopAPNSPayload(type: .carbs, carbsAmount: 30, absorptionTime: 3, consumedDate: now.addingTimeInterval(-600), otp: "123456")
        let json = LoopAPNSService.carbsCommandPayload(payload, now: now)
        #expect(Set(json.keys) == headerKeys.union(["carbs-entry", "absorption-time", "start-time"]))
        #expect(json["carbs-entry"] as? Double == 30)
        #expect(json["absorption-time"] as? Double == 3)
        #expect(json["otp"] as? String == "123456")
        #expect(json["remote-address"] as? String == "LoopFollow")
        #expect(json["entered-by"] as? String == "LoopFollow")
        #expect(json["notes"] as? String == "Sent via LoopFollow APNS")
        #expect(json["sent-at"] as? String == "2023-11-14T22:13:20.000Z")
        #expect(json["expiration"] as? String == "2023-11-14T22:18:20.000Z")
        #expect(json["start-time"] as? String == "2023-11-14T22:03:20.000Z")
        #expect(json["alert"] as? String == "Remote Carbs Entry: 30.0 grams\nAbsorption Time: 3.0 hours")
    }

    @Test("bolus payload carries the loop.js keys")
    func bolusKeys() {
        let json = LoopAPNSService.bolusCommandPayload(LoopAPNSPayload(type: .bolus, bolusAmount: 1.25, otp: "123456"), now: now)
        #expect(Set(json.keys) == headerKeys.union(["bolus-entry"]))
        #expect(json["bolus-entry"] as? Double == 1.25)
        #expect(json["alert"] as? String == "Remote Bolus Entry: 1.25 U")
    }

    @Test("carbs delete addresses the entry by sync identifier")
    func deleteKeys() {
        let json = LoopAPNSService.carbsDeleteCommandPayload(syncIdentifier: "SYNC-1", otp: "123456", now: now)
        #expect(Set(json.keys) == headerKeys.union(["carbs-delete"]))
        #expect(json["carbs-delete"] as? String == "SYNC-1")
        #expect(json["carbs-entry"] == nil)
    }

    @Test("carbs edit always sends amount, absorption and start time; food type only when set")
    func editKeys() {
        let json = LoopAPNSService.carbsEditCommandPayload(
            syncIdentifier: "SYNC-1",
            carbsAmount: 45,
            absorptionTimeHours: 2.5,
            foodType: nil,
            consumedDate: now.addingTimeInterval(-3600),
            otp: "123456",
            now: now
        )
        #expect(Set(json.keys) == headerKeys.union(["carbs-edit", "carbs-edit-entry", "carbs-edit-absorption-time", "carbs-edit-start-time"]))
        #expect(json["carbs-edit"] as? String == "SYNC-1")
        #expect(json["carbs-edit-entry"] as? Double == 45)
        #expect(json["carbs-edit-absorption-time"] as? Double == 2.5)
        #expect(json["carbs-edit-start-time"] as? String == "2023-11-14T21:13:20.000Z")
        #expect(json["carbs-entry"] == nil)
        #expect(json["start-time"] == nil)

        let withFood = LoopAPNSService.carbsEditCommandPayload(
            syncIdentifier: "SYNC-1", carbsAmount: 45, absorptionTimeHours: 2.5, foodType: "🍕", consumedDate: now, otp: "123456", now: now
        )
        #expect(withFood["carbs-edit-food-type"] as? String == "🍕")
    }
}
