// LoopFollow
// TrioMealTreatmentTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TrioMealTreatmentTests {
    private typealias Entry = [String: AnyObject]

    private let rootID = "11111111-1111-4111-8111-111111111111"
    private let familyID = "22222222-2222-4222-8222-222222222222"

    private func entry(id: String, fpuID: String? = nil, carbs: Double = 45, fat: Double = 0, protein: Double = 0, enteredBy: String = "Trio", eventType: String = "Carb Correction", notes: String? = nil) -> Entry {
        var result: Entry = [
            "_id": "mongo-\(id)" as AnyObject,
            "id": id as AnyObject,
            "enteredBy": enteredBy as AnyObject,
            "eventType": eventType as AnyObject,
            "carbs": carbs as AnyObject,
            "fat": fat as AnyObject,
            "protein": protein as AnyObject,
        ]
        if let fpuID { result["fpuID"] = fpuID as AnyObject }
        if let notes { result["notes"] = notes as AnyObject }
        return result
    }

    @Test("root with fpuID is not a child")
    func root() {
        let meal = TrioMealTreatment(nightscoutEntry: entry(id: rootID, fpuID: familyID, fat: 20, protein: 15, notes: " 📡 "), date: 0)
        #expect(meal?.isFPUChild == false)
        #expect(meal?.mealID.uuidString == rootID)
        #expect(meal?.fpuID?.uuidString == familyID)
        #expect(meal?.fat == 20)
        #expect(meal?.protein == 15)
        #expect(meal?.note == "📡")
        #expect(meal?.nightscoutID == "mongo-\(rootID)")
    }

    @Test("child carries the family id as both id and fpuID")
    func child() {
        let meal = TrioMealTreatment(nightscoutEntry: entry(id: familyID, fpuID: familyID, carbs: 12), date: 0)
        #expect(meal?.isFPUChild == true)
        #expect(meal?.mealID.uuidString == familyID)
    }

    @Test("without fpuID the document is a root")
    func missingFPUID() {
        #expect(TrioMealTreatment(nightscoutEntry: entry(id: rootID), date: 0)?.isFPUChild == false)
        #expect(TrioMealTreatment(nightscoutEntry: entry(id: rootID), date: 0)?.fpuID == nil)
    }

    @Test("rejects non-Trio, non-carb, non-UUID and empty entries")
    func rejects() {
        #expect(TrioMealTreatment(nightscoutEntry: entry(id: rootID, enteredBy: "loop://phone"), date: 0) == nil)
        #expect(TrioMealTreatment(nightscoutEntry: entry(id: rootID, eventType: "Meal Bolus"), date: 0) == nil)
        #expect(TrioMealTreatment(nightscoutEntry: entry(id: "not-a-uuid"), date: 0) == nil)
        #expect(TrioMealTreatment(nightscoutEntry: entry(id: rootID, carbs: 0), date: 0) == nil)
    }

    @Test("edit window is 24 h back and 12 h ahead")
    func window() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func meal(offsetHours: Double) -> TrioMealTreatment? {
            TrioMealTreatment(nightscoutEntry: entry(id: rootID), date: now.timeIntervalSince1970 + offsetHours * 3600)
        }
        #expect(meal(offsetHours: -23)?.isWithinEditWindow(now: now) == true)
        #expect(meal(offsetHours: -25)?.isWithinEditWindow(now: now) == false)
        #expect(meal(offsetHours: 11)?.isWithinEditWindow(now: now) == true)
        #expect(meal(offsetHours: 13)?.isWithinEditWindow(now: now) == false)
    }

    @Test("actions need TRC, a Trio device and both commands advertised")
    func gating() {
        let both = ["meal", "edit_meal", "delete_meal"]
        #expect(TrioMealTreatment.remoteActionsAvailable(remoteType: .trc, device: "Trio", remoteCommands: both) == true)
        #expect(TrioMealTreatment.remoteActionsAvailable(remoteType: .trc, device: "Trio", remoteCommands: ["meal"]) == false)
        #expect(TrioMealTreatment.remoteActionsAvailable(remoteType: .trc, device: "Loop", remoteCommands: both) == false)
        #expect(TrioMealTreatment.remoteActionsAvailable(remoteType: .loopAPNS, device: "Trio", remoteCommands: both) == false)
        #expect(TrioMealTreatment.remoteActionsAvailable(remoteType: .none, device: "Trio", remoteCommands: both) == false)
        #expect(TrioMealTreatment.remoteControlActive(remoteType: .trc, device: "Trio") == true)
        #expect(TrioMealTreatment.remoteControlActive(remoteType: .trc, device: "Loop") == false)
    }
}
