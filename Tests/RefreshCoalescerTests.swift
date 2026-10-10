// LoopFollow
// RefreshCoalescerTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct RefreshCoalescerTests {
    final class ManualScheduler {
        var scheduled: [(delay: TimeInterval, work: () -> Void)] = []

        func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
            scheduled.append((delay, work))
        }

        func runAll() {
            let pending = scheduled
            scheduled.removeAll()
            pending.forEach { $0.work() }
        }
    }

    @Test("first request schedules one call after the delay")
    func firstRequestSchedules() {
        let scheduler = ManualScheduler()
        var fired: [String] = []
        let coalescer = RefreshCoalescer(delay: 20, scheduler: scheduler.schedule) { fired.append($0) }

        coalescer.request(reason: "bg")

        #expect(scheduler.scheduled.count == 1)
        #expect(scheduler.scheduled.first?.delay == 20)
        #expect(fired.isEmpty)
        scheduler.runAll()
        #expect(fired == ["bg"])
        #expect(!coalescer.isPending)
    }

    @Test("repeated requests while pending keep the original deadline")
    func repeatedRequestsDoNotReschedule() {
        let scheduler = ManualScheduler()
        var fired: [String] = []
        let coalescer = RefreshCoalescer(delay: 20, scheduler: scheduler.schedule) { fired.append($0) }

        for _ in 0 ..< 10 {
            coalescer.request(reason: "bg")
        }
        coalescer.request(reason: "overrideChanged")

        #expect(scheduler.scheduled.count == 1)
        scheduler.runAll()
        #expect(fired == ["bg,overrideChanged"])
    }

    @Test("a request after a flush opens a new window")
    func requestAfterFlushSchedulesAgain() {
        let scheduler = ManualScheduler()
        var fired: [String] = []
        let coalescer = RefreshCoalescer(delay: 20, scheduler: scheduler.schedule) { fired.append($0) }

        coalescer.request(reason: "bg")
        scheduler.runAll()
        coalescer.request(reason: "bg")

        #expect(scheduler.scheduled.count == 1)
        scheduler.runAll()
        #expect(fired == ["bg", "bg"])
    }

    @Test("cancel drops the pending call")
    func cancelDropsPending() {
        let scheduler = ManualScheduler()
        var fired: [String] = []
        let coalescer = RefreshCoalescer(delay: 20, scheduler: scheduler.schedule) { fired.append($0) }

        coalescer.request(reason: "bg")
        coalescer.cancel()
        #expect(!coalescer.isPending)
        scheduler.runAll()
        #expect(fired.isEmpty)
    }

    @Test("a request after cancel fires only once")
    func requestAfterCancelFiresOnce() {
        let scheduler = ManualScheduler()
        var fired: [String] = []
        let coalescer = RefreshCoalescer(delay: 20, scheduler: scheduler.schedule) { fired.append($0) }

        coalescer.request(reason: "bg")
        coalescer.cancel()
        coalescer.request(reason: "notLooping")
        scheduler.runAll()

        #expect(fired == ["notLooping"])
    }
}
