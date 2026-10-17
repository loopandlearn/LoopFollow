// LoopFollow
// TreatmentHistoryEntriesTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct TreatmentHistoryEntriesTests {
    private typealias Entry = [String: AnyObject]

    private func history(_ fields: [String: Any]) -> TreatmentHistoryEntries {
        var entry: Entry = ["_id": "ns1" as AnyObject]
        for (key, value) in fields {
            entry[key] = value as AnyObject
        }
        return Treatment.historyEntries(from: entry, date: 100) { 120 }
    }

    @Test("a Meal Bolus yields a carb entry and a bolus entry")
    func mealBolus() {
        let result = history(["eventType": "Meal Bolus", "carbs": 30.0, "insulin": 2.5])
        #expect(result.entries.map(\.type) == [.carb, .bolusManual])
        #expect(result.carb?.id == "ns1-carb")
        #expect(result.bolus?.id == "ns1-bolus")
    }

    @Test("automatic and SMB boluses are listed as automatic")
    func automaticBolus() {
        let automatic = history(["eventType": "Correction Bolus", "insulin": 0.4, "automatic": true])
        #expect(automatic.bolus?.type == .bolusAutomatic)
        #expect(automatic.sawAutomatic)
        #expect(!automatic.sawSMB)

        let smb = history(["eventType": "Correction Bolus", "insulin": 0.4, "type": "SMB"])
        #expect(smb.bolus?.type == .bolusAutomatic)
        #expect(smb.sawSMB)
        #expect(!smb.sawAutomatic)

        let manual = history(["eventType": "Bolus", "insulin": 1.0])
        #expect(manual.bolus?.type == .bolusManual)
        #expect(!manual.sawSMB && !manual.sawAutomatic)
    }

    @Test("entries the Treatments list skips yield nothing")
    func skipped() {
        #expect(history(["eventType": "Carb Correction", "carbs": 0.0]).entries.isEmpty)
        #expect(history(["eventType": "Bolus", "insulin": 0.0]).entries.isEmpty)
        #expect(history(["eventType": "Temporary Override", "duration": 0.0]).entries.isEmpty)
        #expect(history(["eventType": "Temporary Target", "duration": 30.0]).entries.isEmpty)
        #expect(history(["eventType": "Note", "notes": "hello"]).entries.isEmpty)
    }

    @Test("overrides and temp targets with a duration are listed")
    func bands() {
        #expect(history(["eventType": "Temporary Override", "duration": 60.0, "reason": "Run"]).entries.first?.type == .override)
        #expect(history(["eventType": "Temporary Target", "duration": 30.0, "targetBottom": 140.0, "targetTop": 140.0]).entries.first?.type == .tempTarget)
    }
}
