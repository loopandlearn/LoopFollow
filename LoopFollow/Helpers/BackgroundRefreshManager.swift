// LoopFollow
// BackgroundRefreshManager.swift

import BackgroundTasks
import Foundation
import UIKit

class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    private init() {}

    private let taskIdentifier = "\(Bundle.main.bundleIdentifier ?? "com.loopfollow").audiorefresh"

    /// Spacing for the routine health check. iOS treats this as a floor and
    /// schedules on its own budget, so the effective interval is longer.
    private let refreshInterval: TimeInterval = 15 * 60

    /// Serialises the read-modify-write around the pending request, so a routine
    /// request can't land on top of an immediate one.
    private let queue = DispatchQueue(label: "com.LoopFollow.BackgroundRefreshQueue")

    /// True while the pending request asks for the earliest window iOS will give.
    /// Guarded by `queue`.
    private var immediateRequested = false

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleRefreshTask(refreshTask)
        }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        LogManager.shared.log(category: .taskScheduler, message: "BGAppRefreshTask fired")

        // Guard against double setTaskCompleted (Apple documents this as a programming
        // error). The restart below keeps the task open for seconds, so expiration and
        // the main-queue block genuinely race for the flag and it needs a lock.
        let lock = NSLock()
        var completed = false
        let claim: () -> Bool = {
            lock.lock()
            defer { lock.unlock() }
            guard !completed else { return false }
            completed = true
            return true
        }
        let complete: (Bool) -> Void = { success in
            guard claim() else { return }
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            LogManager.shared.log(category: .taskScheduler, message: "BGAppRefreshTask expired")
            complete(false)
        }

        // This task exists only to revive the Silent Tune keep-alive. Reading the mode
        // is safe before storage is confirmed readable: the default is `.silentTune`,
        // so an unhydrated read keeps the check armed rather than cancelling it.
        guard !StorageReadiness.ready.value || Storage.shared.backgroundRefreshType.value == .silentTune else {
            LogManager.shared.log(category: .taskScheduler, message: "Background refresh no longer needed for the current mode; cancelling")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            queue.async { self.immediateRequested = false }
            complete(true)
            return
        }

        // Queue the successor before doing any work, so an early expiration or a
        // crash still leaves a pending request behind.
        queue.async {
            self.immediateRequested = false
            self.submit(earliestBeginDate: Date(timeIntervalSinceNow: self.refreshInterval))
        }

        DispatchQueue.main.async {
            guard let backgroundTask = MainViewController.shared?.backgroundTask else {
                LogManager.shared.log(category: .taskScheduler, message: "No main view controller yet; nothing to check")
                complete(true)
                return
            }
            guard !backgroundTask.isPlaying else {
                // Full level: `.taskScheduler` debug lines are dropped before the file
                // write, and a healthy check should leave a trace of its own.
                LogManager.shared.log(category: .taskScheduler, message: "audio alive, no action needed")
                self.armBackgroundAlerts()
                TaskScheduler.shared.checkTasksNow()
                complete(true)
                return
            }

            LogManager.shared.log(category: .taskScheduler, message: "audio dead, attempting restart")
            // The task must stay open until the restart resolves: completing it here
            // lets iOS suspend the app, and a pending retry would then not run until
            // something else resumes the process — minutes or hours later.
            backgroundTask.restartAudio(reason: "BGAppRefreshTask") { success in
                LogManager.shared.log(
                    category: .taskScheduler,
                    message: success ? "audio restart succeeded" : "audio restart failed"
                )
                // Only on success: a failed restart means suspension is imminent, and
                // dispatching fetches that cannot finish helps nothing.
                if success {
                    self.armBackgroundAlerts()
                    TaskScheduler.shared.checkTasksNow()
                }
                complete(success)
            }
        }
    }

    /// Clears any delivered "App inactive" notification and re-arms the 6/12/18 minute
    /// alerts from this moment. A process launched into the background never ran
    /// `appMovedToBackground`, so this is the only place its alerts are armed.
    private func armBackgroundAlerts() {
        // The task fires while backgrounded, but its work lands on the main queue and
        // the user may have opened the app in between. Alerts belong only to a
        // backgrounded app.
        guard UIApplication.shared.applicationState == .background else { return }
        BackgroundAlertManager.shared.startBackgroundAlert()
    }

    /// Requests the routine health check, leaving an existing pending request alone
    /// when it would run at least as soon. Every background transition calls this, so
    /// the earliest pending request is the one that survives.
    func scheduleRefresh() {
        let desired = Date(timeIntervalSinceNow: refreshInterval)
        BGTaskScheduler.shared.getPendingTaskRequests { [weak self] pending in
            guard let self else { return }
            self.queue.async {
                // Category `.general`: LogManager drops `.taskScheduler` debug lines
                // before the file write, and these belong in a shared log.
                guard !self.immediateRequested else {
                    LogManager.shared.log(category: .general, message: "Keeping the pending immediate refresh request", isDebug: true)
                    return
                }
                if let existing = pending.first(where: { $0.identifier == self.taskIdentifier }) {
                    guard let existingDate = existing.earliestBeginDate else { return }
                    guard existingDate > desired else {
                        LogManager.shared.log(category: .general, message: "Refresh already pending at \(existingDate); leaving it", isDebug: true)
                        return
                    }
                }
                self.submit(earliestBeginDate: desired)
            }
        }
    }

    /// Requests the earliest window iOS is willing to give, used when the audio
    /// keep-alive has been lost and a background refresh is the only route back to
    /// running code.
    func scheduleImmediateRefresh() {
        queue.async {
            // The flag tracks what is actually pending. A submit that throws — as it
            // does when Background App Refresh is switched off — must not leave the
            // routine check suppressed behind a request that was never accepted.
            self.immediateRequested = self.submit(earliestBeginDate: nil)
            LogManager.shared.log(
                category: .taskScheduler,
                message: self.immediateRequested
                    ? "Requested the earliest possible background refresh"
                    : "Could not request a background refresh; no recovery window is pending"
            )
        }
    }

    @discardableResult
    private func submit(earliestBeginDate: Date?) -> Bool {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
            return true
        } catch {
            LogManager.shared.log(category: .taskScheduler, message: "Failed to schedule BGAppRefreshTask: \(error)")
            return false
        }
    }
}
