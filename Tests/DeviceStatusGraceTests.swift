// LoopFollow
// DeviceStatusGraceTests.swift

@testable import LoopFollow
import Testing

struct DeviceStatusGraceTests {
    private let now: Double = 1_000_000

    @Test("a value that was never received is not fresh")
    func neverReceived() {
        #expect(!DeviceStatusGrace.isFresh(0, now: now))
    }

    @Test("a value received less than 15 minutes ago is fresh")
    func withinGracePeriod() {
        #expect(DeviceStatusGrace.isFresh(now, now: now))
        #expect(DeviceStatusGrace.isFresh(now - 14 * 60, now: now))
    }

    @Test("a value received 15 minutes ago or more is not fresh")
    func afterGracePeriod() {
        #expect(!DeviceStatusGrace.isFresh(now - 15 * 60, now: now))
        #expect(!DeviceStatusGrace.isFresh(now - 60 * 60, now: now))
    }
}
