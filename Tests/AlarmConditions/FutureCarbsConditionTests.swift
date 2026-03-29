// LoopFollow
// FutureCarbsConditionTests.swift

import Foundation
@testable import LoopFollow
import Testing

@Suite(.serialized)
struct FutureCarbsConditionTests {
    let cond = FutureCarbsCondition()

    private func resetPending() {
        Storage.shared.pendingFutureCarbs.value = []
    }

    private func carb(minutesFromNow offset: Double, grams: Double = 20, relativeTo now: Date = .init()) -> CarbSample {
        CarbSample(grams: grams, date: now.addingTimeInterval(offset * 60))
    }

    // MARK: - 1. Tracking — future carb within lookahead gets tracked

    @Test("#tracking — future carb within lookahead gets tracked")
    func futureWithinLookaheadTracked() {
        resetPending()
        let now = Date()
        let alarm = Alarm.futureCarbs(threshold: 45, delta: 5)
        let data = AlarmData.withCarbs([carb(minutesFromNow: 10, grams: 20, relativeTo: now)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)
    }

    // MARK: - 2. Firing — pending carb whose time arrives fires

    @Test("#firing — pending carb whose time arrives fires")
    func pendingCarbFires() {
        resetPending()
        let now = Date()
        let pastDate = now.addingTimeInterval(-60) // 1 min ago

        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(carbDate: pastDate.timeIntervalSince1970, grams: 20, observedAt: now.addingTimeInterval(-600).timeIntervalSince1970),
        ]

        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([CarbSample(grams: 20, date: pastDate)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 3. Deleted carb — no fire, removed from pending

    @Test("#deleted carb — no fire, removed from pending")
    func deletedCarbNoFire() {
        resetPending()
        let now = Date()
        let pastDate = now.addingTimeInterval(-60)

        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(carbDate: pastDate.timeIntervalSince1970, grams: 20, observedAt: now.addingTimeInterval(-600).timeIntervalSince1970),
        ]

        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([]) // carb was deleted

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 4. Beyond lookahead — tracked but does not fire

    @Test("#beyond lookahead — tracked but does not fire")
    func beyondLookaheadTrackedButNoFire() {
        resetPending()
        let now = Date()
        let alarm = Alarm.futureCarbs(threshold: 45)
        let data = AlarmData.withCarbs([carb(minutesFromNow: 60, grams: 20, relativeTo: now)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        // Carb is tracked (to prevent re-observation with fresh observedAt)
        // but will never fire because original distance > lookahead
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)
    }

    // MARK: - 5. Below min grams — carb ignored

    @Test("#below min grams — carb ignored")
    func belowMinGramsIgnored() {
        resetPending()
        let now = Date()
        let alarm = Alarm.futureCarbs(delta: 5)
        let data = AlarmData.withCarbs([carb(minutesFromNow: 10, grams: 3, relativeTo: now)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 6. Past carb — not tracked

    @Test("#past carb — not tracked")
    func pastCarbNotTracked() {
        resetPending()
        let now = Date()
        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([carb(minutesFromNow: -5, grams: 20, relativeTo: now)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 7. Stale cleanup — entry observed > 2h ago is removed

    @Test("#stale cleanup — entry observed > 2h ago is removed")
    func staleCleanup() {
        resetPending()
        let now = Date()
        let futureDate = now.addingTimeInterval(300) // still in the future

        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(carbDate: futureDate.timeIntervalSince1970, grams: 20, observedAt: now.addingTimeInterval(-3 * 3600).timeIntervalSince1970),
        ]

        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 8. Multiple carbs — only one fires per tick

    @Test("#multiple carbs — only one fires per tick")
    func multipleOnlyOnePerTick() {
        resetPending()
        let now = Date()
        let past1 = now.addingTimeInterval(-60)
        let past2 = now.addingTimeInterval(-120)

        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(carbDate: past1.timeIntervalSince1970, grams: 20, observedAt: now.addingTimeInterval(-600).timeIntervalSince1970),
            PendingFutureCarb(carbDate: past2.timeIntervalSince1970, grams: 30, observedAt: now.addingTimeInterval(-600).timeIntervalSince1970),
        ]

        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([
            CarbSample(grams: 20, date: past1),
            CarbSample(grams: 30, date: past2),
        ])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(result)
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)
    }

    // MARK: - 9. Second tick fires second carb

    @Test("#second tick fires second carb")
    func secondTickFiresSecond() {
        resetPending()
        let now = Date()
        let past1 = now.addingTimeInterval(-60)
        let past2 = now.addingTimeInterval(-120)

        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(carbDate: past1.timeIntervalSince1970, grams: 20, observedAt: now.addingTimeInterval(-600).timeIntervalSince1970),
            PendingFutureCarb(carbDate: past2.timeIntervalSince1970, grams: 30, observedAt: now.addingTimeInterval(-600).timeIntervalSince1970),
        ]

        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([
            CarbSample(grams: 20, date: past1),
            CarbSample(grams: 30, date: past2),
        ])

        // First tick
        let result1 = cond.evaluate(alarm: alarm, data: data, now: now)
        #expect(result1)
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)

        // Second tick
        let result2 = cond.evaluate(alarm: alarm, data: data, now: now)
        #expect(result2)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 10. Duplicate carb not double-tracked

    @Test("#duplicate carb not double-tracked")
    func duplicateNotDoubleTracked() {
        resetPending()
        let now = Date()
        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([carb(minutesFromNow: 10, grams: 20, relativeTo: now)])

        _ = cond.evaluate(alarm: alarm, data: data, now: now)
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)

        _ = cond.evaluate(alarm: alarm, data: data, now: now)
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)
    }

    // MARK: - 11. Sliding window — carb outside lookahead never fires

    @Test("#sliding window — carb outside lookahead never fires")
    func slidingWindowNeverFires() {
        resetPending()
        let t0 = Date()
        let alarm = Alarm.futureCarbs(threshold: 10) // 10-minute lookahead
        let carbDate = t0.addingTimeInterval(15 * 60) // 15 min in future
        let carbSample = CarbSample(grams: 20, date: carbDate)

        // Tick at T+0: carb is 15 min away, outside 10-min window but tracked
        let data = AlarmData.withCarbs([carbSample])
        let r0 = cond.evaluate(alarm: alarm, data: data, now: t0)
        #expect(!r0)
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)

        // Tick at T+5min: carb is now 10 min away (inside window), but
        // original distance was 15 min — must NOT fire
        let t1 = t0.addingTimeInterval(5 * 60)
        let r1 = cond.evaluate(alarm: alarm, data: data, now: t1)
        #expect(!r1)

        // Tick at T+15min: carb is due — still must NOT fire
        let t2 = t0.addingTimeInterval(15 * 60)
        let r2 = cond.evaluate(alarm: alarm, data: data, now: t2)
        #expect(!r2)
        // Entry should be removed (due, outside original window)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 12. Due entry outside original window removed without firing

    @Test("#due entry outside original window removed without firing")
    func dueOutsideWindowRemovedNoFire() {
        resetPending()
        let now = Date()
        let pastDate = now.addingTimeInterval(-60) // 1 min ago

        // Entry was observed 20 min before its carb date (outside 10-min window)
        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(
                carbDate: pastDate.timeIntervalSince1970,
                grams: 20,
                observedAt: pastDate.timeIntervalSince1970 - 20 * 60
            ),
        ]

        let alarm = Alarm.futureCarbs(threshold: 10)
        let data = AlarmData.withCarbs([CarbSample(grams: 20, date: pastDate)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
    }

    // MARK: - 13. Stale entry with existing carb is not evicted

    @Test("#stale entry with existing carb is not evicted")
    func staleWithExistingCarbNotEvicted() {
        resetPending()
        let now = Date()
        let futureDate = now.addingTimeInterval(300) // 5 min in the future

        // Entry observed 3 hours ago, but carb still exists in recentCarbs
        Storage.shared.pendingFutureCarbs.value = [
            PendingFutureCarb(
                carbDate: futureDate.timeIntervalSince1970,
                grams: 20,
                observedAt: now.addingTimeInterval(-3 * 3600).timeIntervalSince1970
            ),
        ]

        let alarm = Alarm.futureCarbs()
        let data = AlarmData.withCarbs([CarbSample(grams: 20, date: futureDate)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        // Entry must survive — carb still exists, don't evict
        #expect(Storage.shared.pendingFutureCarbs.value.count == 1)
    }
}
