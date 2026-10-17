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
        cache: PumpReservoirCache? = nil,
        at date: Date? = nil
    ) -> PumpReservoirResolver.Resolution {
        PumpReservoirResolver.resolve(
            reservoir: reservoir,
            pumpID: pumpID,
            manufacturer: manufacturer,
            model: model,
            cache: cache,
            now: date ?? now
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

    @Test("a volume reported right after a pod change is shown but not trusted once stale")
    func podChangeCarryoverIsDiscarded() {
        // Loop's first records for a new pod still carry the previous pod's final volume.
        let carryover = resolve(reservoir: 9.9, cache: PumpReservoirCache(pumpID: "17CB71F6", pumpSince: now.addingTimeInterval(-3 * 24 * 60 * 60), reading: nil))
        #expect(carryover.state == .units(9.9))
        #expect(carryover.cache?.pumpID == pump)

        let laterOnTheSamePod = resolve(cache: carryover.cache, at: now.addingTimeInterval(31 * 60))
        #expect(laterOnTheSamePod.state == .aboveReportingLimit)
        #expect(laterOnTheSamePod.cache?.pumpID == pump)
        #expect(laterOnTheSamePod.cache?.reading == nil)
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

    @Test("a pump with no pod paired is not an identity to cache against")
    func unknownPumpID() {
        let result = resolve(pumpID: "Unknown", cache: cache(units: 9.9, readingAge: 5 * 60))
        #expect(result.state == .aboveReportingLimit)
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
}
