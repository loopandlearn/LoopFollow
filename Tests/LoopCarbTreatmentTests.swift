// LoopFollow
// LoopCarbTreatmentTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct LoopCarbTreatmentTests {
    private typealias Entry = [String: AnyObject]

    private func entry(enteredBy: String = "loop://phone", eventType: String = "Carb Correction", syncIdentifier: String? = "SYNC-1", carbs: Double = 30, absorption: Double? = 180, foodType: String? = "🍕") -> Entry {
        var result: Entry = [
            "_id": "mongo" as AnyObject,
            "enteredBy": enteredBy as AnyObject,
            "eventType": eventType as AnyObject,
            "carbs": carbs as AnyObject,
        ]
        if let syncIdentifier { result["syncIdentifier"] = syncIdentifier as AnyObject }
        if let absorption { result["absorptionTime"] = absorption as AnyObject }
        if let foodType { result["foodType"] = foodType as AnyObject }
        return result
    }

    @Test("parses a Loop carb entry")
    func parses() {
        let carb = LoopCarbTreatment(nightscoutEntry: entry(), date: 100)
        #expect(carb?.syncIdentifier == "SYNC-1")
        #expect(carb?.carbs == 30)
        #expect(carb?.absorptionHours == 3)
        #expect(carb?.foodType == "🍕")
        #expect(carb?.nightscoutID == "mongo")
    }

    @Test("rejects entries Loop cannot address")
    func rejects() {
        #expect(LoopCarbTreatment(nightscoutEntry: entry(enteredBy: "Trio"), date: 0) == nil)
        #expect(LoopCarbTreatment(nightscoutEntry: entry(syncIdentifier: nil), date: 0) == nil)
        #expect(LoopCarbTreatment(nightscoutEntry: entry(eventType: "Meal Bolus"), date: 0) == nil)
        #expect(LoopCarbTreatment(nightscoutEntry: entry(carbs: 0), date: 0) == nil)
    }

    @Test("edit window is 23 h back and 1 h ahead")
    func window() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func carb(offsetHours: Double) -> LoopCarbTreatment? {
            LoopCarbTreatment(nightscoutEntry: entry(), date: now.timeIntervalSince1970 + offsetHours * 3600)
        }
        #expect(carb(offsetHours: -22)?.isWithinEditWindow(now: now) == true)
        #expect(carb(offsetHours: -24)?.isWithinEditWindow(now: now) == false)
        #expect(carb(offsetHours: 0.5)?.isWithinEditWindow(now: now) == true)
        #expect(carb(offsetHours: 2)?.isWithinEditWindow(now: now) == false)
    }

    @Test("actions need Loop APNS, a Loop device and both commands advertised")
    func gating() {
        let both = ["carbs-delete", "carbs-edit"]
        #expect(LoopCarbTreatment.remoteActionsAvailable(remoteType: .loopAPNS, device: "Loop", remoteCommands: both) == true)
        #expect(LoopCarbTreatment.remoteActionsAvailable(remoteType: .loopAPNS, device: "Loop", remoteCommands: ["carbs-delete"]) == false)
        #expect(LoopCarbTreatment.remoteActionsAvailable(remoteType: .loopAPNS, device: "Loop", remoteCommands: []) == false)
        #expect(LoopCarbTreatment.remoteActionsAvailable(remoteType: .loopAPNS, device: "Trio", remoteCommands: both) == false)
        #expect(LoopCarbTreatment.remoteActionsAvailable(remoteType: .trc, device: "Loop", remoteCommands: both) == false)
        #expect(LoopCarbTreatment.remoteActionsAvailable(remoteType: .none, device: "Loop", remoteCommands: both) == false)
        #expect(LoopCarbTreatment.remoteControlActive(remoteType: .loopAPNS, device: "Loop") == true)
        #expect(LoopCarbTreatment.remoteControlActive(remoteType: .loopAPNS, device: "Trio") == false)
    }
}
