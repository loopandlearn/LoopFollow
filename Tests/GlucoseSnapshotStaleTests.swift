// LoopFollow
// GlucoseSnapshotStaleTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct GlucoseSnapshotStaleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func snapshot(ageSeconds: TimeInterval) -> GlucoseSnapshot {
        GlucoseSnapshot(
            glucose: 120,
            delta: 0,
            trend: .flat,
            updatedAt: now.addingTimeInterval(-ageSeconds),
            iob: nil,
            cob: nil,
            projected: nil,
            unit: .mgdl,
            isNotLooping: false,
        )
    }

    @Test("A reading turns stale at exactly 12 minutes, as on the main screen")
    func staleBoundary() {
        #expect(!snapshot(ageSeconds: 12 * 60 - 1).isStale(at: now))
        #expect(snapshot(ageSeconds: 12 * 60).isStale(at: now))
        #expect(snapshot(ageSeconds: 3600).isStale(at: now))
    }

    @Test("A fresh reading goes stale 12 minutes after it was taken, not after the update")
    func staleDateFollowsReading() {
        let fresh = snapshot(ageSeconds: 5 * 60)
        #expect(fresh.staleDate(now: now) == fresh.updatedAt.addingTimeInterval(12 * 60))
    }

    @Test("A reading about to turn stale keeps its exact stale date")
    func staleDateNotDelayedNearBoundary() {
        let aging = snapshot(ageSeconds: 12 * 60 - 30)
        #expect(aging.staleDate(now: now) == now.addingTimeInterval(30))
    }

    @Test("An old reading never gets a stale date in the past")
    func staleDateNeverInPast() {
        #expect(snapshot(ageSeconds: 12 * 60).staleDate(now: now) > now)
        #expect(snapshot(ageSeconds: 3600).staleDate(now: now) > now)
    }

    @Test("The watch and the Live Activity share one stale threshold")
    func watchUsesSharedThreshold() {
        #expect(WatchFormat.staleAfter == GlucoseSnapshot.staleAfter)
    }
}
