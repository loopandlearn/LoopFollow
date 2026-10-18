// LoopFollow
// RefreshCoalescer.swift

import Foundation

/// Coalesces refresh requests into one trailing call per window.
///
/// The first request schedules the call; requests that arrive while it is
/// pending join it without moving its deadline. A steady stream of requests
/// therefore flushes once per window. Not thread-safe: use from one queue.
final class RefreshCoalescer {
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Void

    private let delay: TimeInterval
    private let scheduler: Scheduler
    private let action: (String) -> Void
    private var pendingReasons: [String] = []
    private var generation = 0

    init(
        delay: TimeInterval,
        scheduler: @escaping Scheduler = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        },
        action: @escaping (String) -> Void
    ) {
        self.delay = delay
        self.scheduler = scheduler
        self.action = action
    }

    var isPending: Bool { !pendingReasons.isEmpty }

    func request(reason: String) {
        let wasPending = isPending
        if !pendingReasons.contains(reason) {
            pendingReasons.append(reason)
        }
        guard !wasPending else { return }

        let scheduledGeneration = generation
        scheduler(delay) { [weak self] in
            guard let self, self.generation == scheduledGeneration else { return }
            let reason = self.pendingReasons.joined(separator: ",")
            self.cancel()
            self.action(reason)
        }
    }

    func cancel() {
        pendingReasons.removeAll()
        generation += 1
    }
}
