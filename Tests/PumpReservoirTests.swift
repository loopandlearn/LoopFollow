// LoopFollow
// PumpReservoirTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct PumpReservoirTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let pump = "17CB71F7"

    private func resolve(
        reservoir: Double? = nil,
        pumpID: String? = "17CB71F7",
        manufacturer: String? = "Insulet",
        model: String? = "Omnipod DASH",
        displayOverride: String? = nil,
        cache: PumpReservoirCache? = nil,
        at date: Date? = nil
    ) -> PumpReservoirResolver.Resolution {
        PumpReservoirResolver.resolve(
            reservoir: reservoir,
            pumpID: pumpID,
            manufacturer: manufacturer,
            model: model,
            displayOverride: displayOverride,
            cache: cache,
            date: date ?? now
        )
    }

    /// A pump that came online `settledFor` ago and reported `units` `readingAge` ago.
    private func cache(units: Double, readingAge: TimeInterval, settledFor: TimeInterval = 60 * 60) -> PumpReservoirCache {
        PumpReservoirCache(
            pumpID: pump,
            pumpSince: now.addingTimeInterval(-settledFor),
            reading: .init(units: units, date: now.addingTimeInterval(-readingAge))
        )
    }

    @Test("a reported volume is used and kept for the pump it came from")
    func reportedVolume() {
        let result = resolve(reservoir: 12.5)
        #expect(result.state == .units(12.5))
        #expect(result.cache?.pumpID == pump)
        #expect(result.cache?.reading == .init(units: 12.5, date: now))
    }

    @Test("zero is a volume, not a missing reading")
    func zeroVolume() {
        #expect(resolve(reservoir: 0).state == .units(0))
    }

    @Test("a record without a volume reuses a recent reading from the same pump")
    func carriesRecentReading() {
        let result = resolve(cache: cache(units: 9.9, readingAge: 25 * 60))
        #expect(result.state == .units(9.9))
        #expect(result.cache?.reading?.units == 9.9)
    }

    @Test("a reading older than 30 minutes is not shown, and does not become 50+")
    func staleReadingIsUnknown() {
        let result = resolve(cache: cache(units: 9.9, readingAge: 31 * 60))
        #expect(result.state == .unknown)
        // Kept, so the next record still reads as unknown.
        #expect(result.cache?.reading?.units == 9.9)
        #expect(resolve(cache: result.cache, at: now.addingTimeInterval(5 * 60)).state == .unknown)
    }

    @Test("a reading dated in the future is treated as stale")
    func futureReadingIsUnknown() {
        #expect(resolve(cache: cache(units: 9.9, readingAge: -60 * 60)).state == .unknown)
    }

    @Test("a volume reported right after a pod change is the previous pod's and is not shown")
    func podChangeCarryoverIsIgnored() {
        // Loop's first records for a new pod still carry the previous pod's final volume.
        let previousPod = PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60), reading: .init(units: 25.6, date: now.addingTimeInterval(-5 * 60)))
        var result = resolve(reservoir: 25.5, cache: previousPod)
        #expect(result.state == .aboveReportingLimit)
        #expect(result.cache?.pumpID == pump)
        #expect(result.cache?.reading == nil)

        result = resolve(reservoir: 25.5, cache: result.cache, at: now.addingTimeInterval(10 * 60))
        #expect(result.state == .aboveReportingLimit)
        #expect(result.cache?.reading == nil)

        result = resolve(cache: result.cache, at: now.addingTimeInterval(15 * 60))
        #expect(result.state == .aboveReportingLimit)
        #expect(result.cache?.isSettled == true)
    }

    @Test("a new pod's volumes count once it has uploaded a record without one")
    func podChangeSettlesOnMissingVolume() {
        let changed = resolve(reservoir: 25.5, cache: PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60)))
        let gap = resolve(cache: changed.cache, at: now.addingTimeInterval(5 * 60))
        let reported = resolve(reservoir: 48.5, cache: gap.cache, at: now.addingTimeInterval(10 * 60))
        #expect(reported.state == .units(48.5))
        #expect(reported.cache?.reading?.units == 48.5)
    }

    @Test("a new pod's volumes count 15 minutes after it appeared")
    func podChangeSettlesAfterTime() {
        let changed = resolve(reservoir: 25.5, cache: PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60)))
        #expect(resolve(reservoir: 25.5, cache: changed.cache, at: now.addingTimeInterval(14 * 60)).state == .aboveReportingLimit)
        #expect(resolve(reservoir: 48.5, cache: changed.cache, at: now.addingTimeInterval(15 * 60)).state == .units(48.5))
    }

    @Test("a pump change is seen across records that name no pump")
    func podChangeAcrossUnknown() {
        let previousPod = PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60), reading: .init(units: 43.3, date: now.addingTimeInterval(-10 * 60)))
        let pairing = resolve(pumpID: "Unknown", cache: previousPod, at: now.addingTimeInterval(-5 * 60))
        #expect(pairing.cache == previousPod)
        #expect(resolve(reservoir: 42.9, cache: pairing.cache).state == .aboveReportingLimit)
    }

    @Test("a pump seen with nothing stored has its volume taken as its own")
    func firstSeenPumpIsSettled() {
        let result = resolve(reservoir: 25.5)
        #expect(result.state == .units(25.5))
        #expect(result.cache?.isSettled == true)
    }

    @Test("a pump that reports its volume in every record is used right after a change")
    func otherPumpChangeIsSettled() {
        let previous = PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60))
        #expect(resolve(reservoir: 180, manufacturer: "Medtronic", model: "723", cache: previous).state == .units(180))
    }

    @Test("a pod change drops the previous pod's reading")
    func podChangeDropsReading() {
        let previousPod = PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60), reading: .init(units: 9.9, date: now.addingTimeInterval(-5 * 60)))
        let result = resolve(cache: previousPod)
        #expect(result.state == .aboveReportingLimit)
        #expect(result.cache?.reading == nil)
        #expect(result.cache?.pumpSince == now)
    }

    @Test("an Omnipod that has never reported a volume reads as 50+")
    func omnipodWithoutReading() {
        #expect(resolve().state == .aboveReportingLimit)
        #expect(resolve(manufacturer: "Insulet", model: "Dash").state == .aboveReportingLimit)
        #expect(resolve(manufacturer: nil, model: "Omnipod").state == .aboveReportingLimit)
    }

    @Test("a pump that reports its volume gives no number when the field is missing")
    func otherPumpWithoutReading() {
        let result = resolve(manufacturer: "Medtronic", model: "723")
        #expect(result.state == .unknown)
        #expect(result.cache?.pumpID == pump)
        #expect(result.cache?.reading == nil)
    }

    @Test("an uploader that names no pump resolves from the record alone")
    func unidentifiedPump() {
        // Trio and iAPS name no pump, so there is nothing to tie a reading to.
        let withVolume = resolve(reservoir: 18, pumpID: nil, manufacturer: nil, model: nil)
        #expect(withVolume.state == .units(18))
        #expect(withVolume.cache == nil)

        let withoutVolume = resolve(pumpID: nil, manufacturer: nil, model: nil)
        #expect(withoutVolume.state == .aboveReportingLimit)
        #expect(withoutVolume.cache == nil)
    }

    @Test("an Omnipod with no pod paired shows no volume and keeps the stored pump")
    func unknownPumpID() {
        let stored = cache(units: 9.9, readingAge: 5 * 60)
        let result = resolve(pumpID: "Unknown", cache: stored)
        #expect(result.state == .unknown)
        #expect(result.cache == stored)
    }

    @Test("a volume uploaded while no pod is paired is the previous pod's")
    func unknownPumpIDWithVolume() {
        let stored = cache(units: 12.6, readingAge: 5 * 60)
        let result = resolve(reservoir: 12.5, pumpID: "Unknown", cache: stored)
        #expect(result.state == .unknown)
        #expect(result.cache == stored)
    }

    @Test("a status Loop shows in place of the reservoir is shown instead of a volume")
    func displayOverride() {
        let stored = cache(units: 9.9, readingAge: 5 * 60)
        let result = resolve(displayOverride: " Signal Loss ", cache: stored)
        #expect(result.state == .status("Signal Loss"))
        #expect(result.cache == stored)
    }

    @Test("a new pod finishing setup shows its status and is still seen as a change")
    func displayOverrideDuringSetup() {
        let previousPod = PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60), reading: .init(units: 21.0, date: now.addingTimeInterval(-5 * 60)))
        let setup = resolve(reservoir: 21.0, displayOverride: "Finish Setup", cache: previousPod)
        #expect(setup.state == .status("Finish Setup"))
        #expect(setup.cache?.pumpID == pump)
        #expect(setup.cache?.reading == nil)
        #expect(resolve(reservoir: 21.0, cache: setup.cache, at: now.addingTimeInterval(5 * 60)).state == .aboveReportingLimit)
    }

    @Test("an empty status shows the volume")
    func emptyDisplayOverride() {
        #expect(resolve(reservoir: 21.0, displayOverride: "  ", cache: cache(units: 21.0, readingAge: 5 * 60)).state == .units(21.0))
    }

    @Test("a pump Loop names Unknown that reports its volume in every record shows it")
    func unknownPumpIDOtherPump() {
        let result = resolve(reservoir: 185.6, pumpID: "Unknown", manufacturer: "Medtrum", model: "MD8201")
        #expect(result.state == .units(185.6))
        #expect(result.cache == nil)
    }

    @Test("a settled pump stays unknown for as long as it reports nothing")
    func settledUnknownPersists() {
        var result = resolve(cache: cache(units: 9.9, readingAge: 31 * 60))
        #expect(result.state == .unknown)
        result = resolve(cache: result.cache, at: now.addingTimeInterval(3 * 60 * 60))
        #expect(result.state == .unknown)
    }

    @Test("a settled pump recovers as soon as it reports again")
    func settledUnknownRecovers() {
        let stale = resolve(cache: cache(units: 9.9, readingAge: 31 * 60))
        let reported = resolve(reservoir: 8.4, cache: stale.cache, at: now.addingTimeInterval(5 * 60))
        #expect(reported.state == .units(8.4))
        #expect(reported.cache?.reading?.units == 8.4)
    }

    @Test("the cache survives a round trip through storage")
    func cacheRoundTrips() throws {
        let original = cache(units: 12.5, readingAge: 5 * 60)
        let decoded = try JSONDecoder().decode(PumpReservoirCache.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test("a cache stored without the settled flag decodes as settled")
    func cacheDecodesWithoutSettledFlag() throws {
        let json = #"{"pumpID":"17CB71F7","pumpSince":0}"#
        let decoded = try JSONDecoder().decode(PumpReservoirCache.self, from: Data(json.utf8))
        #expect(decoded.isSettled)
        #expect(decoded.reading == nil)
    }
}
