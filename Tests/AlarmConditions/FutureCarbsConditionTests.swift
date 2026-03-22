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

    // MARK: - 4. Beyond lookahead — carb ignored

    @Test("#beyond lookahead — carb ignored")
    func beyondLookaheadIgnored() {
        resetPending()
        let now = Date()
        let alarm = Alarm.futureCarbs(threshold: 45)
        let data = AlarmData.withCarbs([carb(minutesFromNow: 60, grams: 20, relativeTo: now)])

        let result = cond.evaluate(alarm: alarm, data: data, now: now)

        #expect(!result)
        #expect(Storage.shared.pendingFutureCarbs.value.isEmpty)
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
}
