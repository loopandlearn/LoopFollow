// LoopFollow
// NightscoutTreatmentDeduplicationTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
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

    @Test("known-through id is the greatest valid _id over all entries")
    func knownThroughID() {
        let entries: [Entry] = [
            entry("6566a3c0a1b2c3d4e5f60718", eventType: "Temp Basal"),
            entry("6566a3c0a1b2c3d4e5f60719", eventType: "Note"),
            entry("6566a3c0a1b2c3d4e5f60719", eventType: "Note"),
            entry("6566a3c0a1b2c3d4e5f6071"),
            entry("ffffffffffffffffffffffffff"),
            entry("zz66a3c0a1b2c3d4e5f60718"),
            entry("NA"),
        ]
        #expect(MainViewController.knownThroughID(entries) == "6566a3c0a1b2c3d4e5f60719")
        #expect(MainViewController.knownThroughID([entry("NA"), entry("")]) == nil)
        #expect(MainViewController.knownThroughID([]) == nil)
    }

    @Test("known-through id skips ids dated more than 5 minutes ahead")
    func knownThroughIDSkipsFutureIDs() {
        let now = Date(timeIntervalSince1970: 0x6566_A3C0)
        let entries: [Entry] = [
            entry("6566a3c0a1b2c3d4e5f60718"),
            entry("6566a4eca1b2c3d4e5f60718"),
            entry("6566a4eda1b2c3d4e5f60718"),
            entry("ffffffffa1b2c3d4e5f60718"),
        ]
        #expect(MainViewController.knownThroughID(entries, now: now) == "6566a4eca1b2c3d4e5f60718")
        #expect(MainViewController.knownThroughID([entry("6566a4eda1b2c3d4e5f60718")], now: now) == nil)
    }

    @Test("a download stores its marker only while its site is current")
    func knownThroughIDBelongsToItsSite() {
        let marker = Observable.shared.treatmentsKnownThroughID
        let saved = marker.value
        defer { marker.value = saved }
        let site = MainViewController.TreatmentsSite(url: "https://a.example", token: "token-a", hubURL: "")
        let entries = [entry("6566a3c0a1b2c3d4e5f60718")]
        let now = Date(timeIntervalSince1970: 0x6566_A3C0)

        marker.value = nil
        MainViewController.storeKnownThroughID(entries, fetchedFrom: site, current: site, now: now)
        #expect(marker.value == "6566a3c0a1b2c3d4e5f60718")

        let changes = [
            MainViewController.TreatmentsSite(url: "https://b.example", token: "token-a", hubURL: ""),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "token-b", hubURL: ""),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "token-a", hubURL: "https://hub.example"),
        ]
        for current in changes {
            marker.value = nil
            MainViewController.storeKnownThroughID(entries, fetchedFrom: site, current: current, now: now)
            #expect(marker.value == nil)
        }
    }

    @Test("a download stores no marker after hub mode, the device key or the treatment download changes")
    func knownThroughIDBelongsToHubAndDownload() {
        let marker = Observable.shared.treatmentsKnownThroughID
        let saved = marker.value
        defer { marker.value = saved }
        let site = MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "https://hub.example", hubMode: true, deviceKey: "key-a")
        let entries = [entry("6566a3c0a1b2c3d4e5f60718")]
        let now = Date(timeIntervalSince1970: 0x6566_A3C0)

        let changes = [
            MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "https://hub.example", hubMode: false, deviceKey: "key-a"),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "https://hub.example", hubMode: true, deviceKey: "key-b"),
        ]
        for current in changes {
            marker.value = nil
            MainViewController.storeKnownThroughID(entries, fetchedFrom: site, current: current, now: now)
            #expect(marker.value == nil)
        }

        marker.value = nil
        MainViewController.storeKnownThroughID(entries, fetchedFrom: site, current: site, downloadsTreatments: false, now: now)
        #expect(marker.value == nil)
    }

    @Test("a phone command carries the marker from when its screen appeared")
    func originMarkerFromScreenAppearance() {
        let marker = Observable.shared.treatmentsKnownThroughID
        let saved = marker.value
        defer { marker.value = saved }
        let seen = "6566a3c0a1b2c3d4e5f60718"
        let otherCaregiversBolus = "6566a3dea1b2c3d4e5f60718"

        marker.value = seen
        let origin = RemoteCommandOrigin.phoneScreenAppeared()
        marker.value = otherCaregiversBolus
        #expect(origin.knownThroughID == seen)
    }

    @Test("a phone command carries the older marker, or whichever one exists")
    func originMarkerOlderOrEither() {
        let site = MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "")
        let seen = "6566a3c0a1b2c3d4e5f60718"
        let origin = RemoteCommandOrigin.phone(screenOpenedWith: seen, site: site)

        #expect(origin.knownThroughID(current: "6566a3dea1b2c3d4e5f60718", currentSite: site) == seen)
        #expect(origin.knownThroughID(current: "6566a3a0a1b2c3d4e5f60718", currentSite: site) == "6566a3a0a1b2c3d4e5f60718")
        #expect(origin.knownThroughID(current: nil, currentSite: site) == seen)
        #expect(RemoteCommandOrigin.phone(screenOpenedWith: nil, site: site).knownThroughID(current: seen, currentSite: site) == seen)
        #expect(RemoteCommandOrigin.phone(screenOpenedWith: nil, site: site).knownThroughID(current: nil, currentSite: site) == nil)
    }

    @Test("a phone command drops the marker from when its screen appeared once the site changed")
    func originMarkerBelongsToItsSite() {
        let site = MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "")
        let origin = RemoteCommandOrigin.phone(screenOpenedWith: "6566a3c0a1b2c3d4e5f60718", site: site)
        let changes = [
            MainViewController.TreatmentsSite(url: "https://b.example", token: "t", hubURL: ""),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "u", hubURL: ""),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "https://hub.example"),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "", hubMode: true),
            MainViewController.TreatmentsSite(url: "https://a.example", token: "t", hubURL: "", deviceKey: "key-b"),
        ]
        for current in changes {
            #expect(origin.knownThroughID(current: nil, currentSite: current) == nil)
            #expect(origin.knownThroughID(current: "6566a3dea1b2c3d4e5f60718", currentSite: current) == "6566a3dea1b2c3d4e5f60718")
        }
    }

    @Test("commands relayed from the watch carry no marker")
    func originMarker() {
        let marker = Observable.shared.treatmentsKnownThroughID
        let saved = marker.value
        defer { marker.value = saved }
        marker.value = "6566a3c0a1b2c3d4e5f60718"
        #expect(RemoteCommandOrigin.watch.knownThroughID == nil)

        let relayed = LoopAPNSCommands.bolusCommandPayload(
            LoopAPNSPayload(type: .bolus, bolusAmount: 1, otp: "123456"),
            knownThroughID: RemoteCommandOrigin.watch.knownThroughID
        )
        #expect(relayed.keys.contains("known-through-id") == false)
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
