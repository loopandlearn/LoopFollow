// LoopFollow
// TaskScheduler.swift

import Foundation

enum TaskID: CaseIterable {
    case profile
    case deviceStatus
    case treatments
    case fetchBG
    case minAgoUpdate
    case calendarWrite
    case alarmCheck
    case telemetry
    case dbSize
}

struct ScheduledTask {
    var nextRun: Date
    var action: () -> Void
}

class TaskScheduler {
    static let shared = TaskScheduler()

    private let queue = DispatchQueue(label: "com.LoopFollow.TaskSchedulerQueue")

    private var tasks: [TaskID: ScheduledTask] = [:]
    private var currentTimer: DispatchSourceTimer?

    /// When tasks last fired. `minAgoUpdate` reschedules itself at most 60s out, so
    /// with runtime this advances at least once a minute; a larger jump means the
    /// process was suspended and is the window the background alerts fire in.
    private var lastFireDate: Date?

    /// Counterpart to `lastFireDate` that includes time asleep and cannot be moved by
    /// a clock correction. The difference between the two measures a clock step.
    private var lastFireUptime: UInt64?

    /// Above normal tick jitter, below the 6-minute first background alert.
    private let runtimeGapThreshold: TimeInterval = 120

    /// Queue-confined park tracking. A normal park clears within milliseconds, so a
    /// survivor at this age is wedged or was suspended mid-park.
    private var parkedSince: Date?
    private var parkedReporter: DispatchWorkItem?
    private let parkedReportDelay: TimeInterval = 5

    private init() {}

    // MARK: - Public API

    func scheduleTask(id: TaskID, nextRun: Date, action: @escaping () -> Void) {
        queue.async {
            let timeString = self.formatTime(nextRun)
            LogManager.shared.log(category: .taskScheduler, message: "scheduleTask(\(id)): next run = \(timeString)", isDebug: true)

            self.tasks[id] = ScheduledTask(nextRun: nextRun, action: action)
            self.rescheduleTimer()
        }
    }

    func rescheduleTask(id: TaskID, to newRunDate: Date) {
        // let timeString = formatTime(newRunDate)
        // LogManager.shared.log(category: .taskScheduler, message: "Reschedule Task \(id): next run = \(timeString)", isDebug: true)

        queue.async {
            guard var existingTask = self.tasks[id] else { return }
            existingTask.nextRun = newRunDate
            self.tasks[id] = existingTask
            self.checkTasksNow()
        }
    }

    func checkTasksNow() {
        queue.async {
            self.fireOverdueTasks()
            self.rescheduleTimer()
        }
    }

    // MARK: - Private

    private func rescheduleTimer() {
        currentTimer?.cancel()
        currentTimer = nil

        guard let (_, earliestTask) = tasks.min(by: { $0.value.nextRun < $1.value.nextRun }) else {
            LogManager.shared.log(category: .taskScheduler, message: "No tasks, no timer scheduled.")
            return
        }

        if earliestTask.nextRun == .distantFuture {
            noteTimerParked()
        } else {
            clearTimerParked()
        }

        let interval = earliestTask.nextRun.timeIntervalSinceNow
        let safeInterval = max(interval, 0)

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + safeInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.fireOverdueTasks()
            self.rescheduleTimer()
        }
        currentTimer = timer
        timer.resume()
    }

    private func fireOverdueTasks() {
        BackgroundAlertManager.shared.scheduleBackgroundAlert()

        let now = Date()
        noteRuntimeGap(at: now)

        for taskID in TaskID.allCases {
            guard let task = tasks[taskID], task.nextRun <= now else {
                continue
            }

            var updatedTask = task
            updatedTask.nextRun = .distantFuture
            tasks[taskID] = updatedTask

            // LogManager.shared.log(category: .taskScheduler, message: "Executing Task \(taskID)", isDebug: true)

            DispatchQueue.main.async {
                task.action()
            }
        }
    }

    /// `fireOverdueTasks` parks a task at `.distantFuture` and its action reschedules
    /// it asynchronously, so every task being parked at once is normal for the
    /// milliseconds in between. A park outliving that leaves nothing to wake the timer,
    /// so it is reported by duration and the routine case stays silent.
    private func noteTimerParked() {
        guard parkedSince == nil else { return }
        let since = Date()
        parkedSince = since
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.parkedSince == since else { return }
            LogManager.shared.log(
                category: .taskScheduler,
                message: "Timer still parked after \(Int(Date().timeIntervalSince(since)))s: every task is awaiting its action to reschedule it"
            )
        }
        parkedReporter = work
        queue.asyncAfter(deadline: .now() + parkedReportDelay, execute: work)
    }

    private func clearTimerParked() {
        parkedReporter?.cancel()
        parkedReporter = nil
        parkedSince = nil
    }

    /// Records one line per lost-runtime window, giving the length of a background
    /// stall directly.
    private func noteRuntimeGap(at now: Date) {
        // CLOCK_MONOTONIC keeps counting while the device sleeps, so it measures a
        // suspension.
        let uptime = clock_gettime_nsec_np(CLOCK_MONOTONIC)
        defer {
            lastFireDate = now
            lastFireUptime = uptime
        }
        guard let last = lastFireDate, let lastUptime = lastFireUptime else { return }
        // Boot time is authoritative: a wall-clock correction must not hide a stall.
        let gap = Double(uptime &- lastUptime) / 1_000_000_000
        let wallGap = now.timeIntervalSince(last)
        guard gap >= runtimeGapThreshold else { return }
        // Silent Tune is the only mode whose invariant is continuous runtime, which is
        // what this measures. `.none` is meant to be suspended and the Bluetooth modes
        // tick at heartbeat cadence, so for both a gap is normal.
        guard Storage.shared.backgroundRefreshType.value == .silentTune else { return }
        let alerts = BackgroundAlertDuration.allCases
            .filter { gap >= $0.rawValue }
            .map { "\(Int($0.rawValue / 60))" }
        let fired = alerts.isEmpty ? "none" : alerts.joined(separator: "/") + " min"
        var message = "Regained runtime after \(Int(gap))s with no scheduler tick; background alerts fired: \(fired)"
        if abs(wallGap - gap) >= 5 {
            message += "; wall clock moved \(Int(wallGap - gap))s relative to boot time"
        }
        LogManager.shared.log(category: .taskScheduler, message: message)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
