// LoopFollow
// NightscoutTreatmentDeduplicationTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct NightscoutTreatmentDeduplicationTests {
    private typealias Entry = [String: AnyObject]

    @Test("keeps Trio FPU siblings with one id and distinct times")
    func keepsFPUOccurrences() {
        let entries = [
            entry("newer", createdAt: "2026-08-16T02:06:00Z"),
            entry("older", createdAt: "2026-08-16T01:06:00Z"),
        ]
        #expect(deduplicatedIDs(entries) == ["newer", "older"])
    }

    @Test("collapses duplicate Nightscout documents and keeps the first")
    func collapsesDuplicates() {
        let entries = [
            entry("first", createdAt: "2026-08-16T01:06:00Z"),
            entry("duplicate", createdAt: "2026-08-16T01:06:00Z"),
        ]
        #expect(deduplicatedIDs(entries) == ["first"])
    }

    @Test("uses normalized effective time and event type")
    func usesLogicalOccurrence() {
        let first = entry("first", timestamp: "2026-08-16T01:06:00Z", createdAt: "2026-08-16T01:05:58Z")
        let equivalent = entry("equivalent", timestamp: "2026-08-16T01:06:00.000Z", createdAt: "2026-08-16T01:06:02Z")
        let createdAtOnly = entry("created-at", timestamp: nil, createdAt: "2026-08-16T01:06:00Z")
        let bolus = entry("bolus", eventType: "Correction Bolus", timestamp: "2026-08-16T01:06:00Z")
        #expect(deduplicatedIDs([first, equivalent, createdAtOnly, bolus]) == ["first", "bolus"])
    }

    @Test("preserves missing identifiers and fallback behavior")
    func preservesFallbacks() {
        let noID = entry("no-id", id: nil)
        let blankID = entry("blank-id", id: "")
        let noTime = [entry("no-time"), entry("no-time-duplicate")]
        let sensor = entry("sensor", eventType: "Sensor Start", timestamp: "2026-08-16T02:00:00Z", createdAt: "2026-08-16T01:00:00Z")
        let sensorDuplicate = entry("sensor-duplicate", eventType: "Sensor Start", timestamp: "2026-08-16T03:00:00Z", createdAt: "2026-08-16T01:00:00Z")
        #expect(deduplicatedIDs([noID, noID, blankID, blankID]) == ["no-id", "no-id", "blank-id", "blank-id"])
        #expect(deduplicatedIDs(noTime) == ["no-time"])
        #expect(deduplicatedIDs([sensor, sensorDuplicate]) == ["sensor"])
    }

    private func deduplicatedIDs(_ entries: [Entry]) -> [String] {
        MainViewController.deduplicatedTreatmentEntries(entries).compactMap { $0["_id"] as? String }
    }

    private func entry(_ mongoID: String, id: String? = "shared-id", eventType: String = "Carb Correction", timestamp: String? = nil, createdAt: String? = nil) -> Entry {
        var result: Entry = [
            "_id": mongoID as AnyObject,
            "eventType": eventType as AnyObject,
        ]
        if let id { result["id"] = id as AnyObject }
        if let timestamp { result["timestamp"] = timestamp as AnyObject }
        if let createdAt { result["created_at"] = createdAt as AnyObject }
        return result
    }
}
