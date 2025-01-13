//
//  TaskScheduler.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

enum TaskID {
    case profile
    case deviceStatus
    case treatments
    case fetchBG
    case minAgoUpdate
    case calendarWrite
    case alarmCheck
}

struct ScheduledTask {
    var nextRun: Date
    var action: () -> Void
}

class TaskScheduler {
    static let shared = TaskScheduler()

    // Thread-safety: a serial queue so we don’t manipulate tasks from multiple threads at once
    private let queue = DispatchQueue(label: "com.LoopFollow.TaskSchedulerQueue")

    private var tasks: [TaskID: ScheduledTask] = [:]
    private var currentTimer: Timer?

    private init() {}

    // MARK: - Public API

    func scheduleTask(id: TaskID, nextRun: Date, action: @escaping () -> Void) {
        queue.async {
            let timeString = self.formatTime(nextRun)
            LogManager.shared.log(category: .taskScheduler, message: "scheduleTask(\(id)): nextRun = \(timeString)")
            
            self.tasks[id] = ScheduledTask(nextRun: nextRun, action: action)
            self.rescheduleTimer()
        }
    }

    func rescheduleTask(id: TaskID, to newRunDate: Date) {
        queue.async {
            guard var existingTask = self.tasks[id] else {
                return
            }
            //let timeString = self.formatTime(newRunDate)
            //LogManager.shared.log(category: .taskScheduler, message: "Reschedule Task \(id), nextRun = \(timeString)")
            existingTask.nextRun = newRunDate
            self.tasks[id] = existingTask
            self.rescheduleTimer()
        }
    }

    func checkTasksNow() {
        queue.async {
            LogManager.shared.log(category: .taskScheduler, message: "CheckTasksNow, Forcing immediate check.")
            self.fireOverdueTasks()
            self.rescheduleTimer()
        }
    }

    // MARK: - Private

    /// Updated signature to include info about who called us, and which task triggered it (if any).
    private func rescheduleTimer() {
        // Invalidate any existing timer
        currentTimer?.invalidate()
        currentTimer = nil

        guard let (_, earliestTask) = tasks.min(by: { $0.value.nextRun < $1.value.nextRun }) else {
            LogManager.shared.log(
                category: .taskScheduler,
                message: "No tasks, no timer scheduled."
            )
            return
        }

        let interval = earliestTask.nextRun.timeIntervalSinceNow
        let safeInterval = max(interval, 0)

        DispatchQueue.main.async {
            self.currentTimer = Timer.scheduledTimer(withTimeInterval: safeInterval, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.queue.async {
                    self.fireOverdueTasks()
                    self.rescheduleTimer()
                }
            }
        }
    }

    private func fireOverdueTasks() {
        let now = Date()
        for (id, task) in tasks {
            if task.nextRun <= now {

//                let scheduledTimeString = formatTime(task.nextRun)
//                let diffSeconds = Int(now.timeIntervalSince(task.nextRun))
//                let diffInfo = diffSeconds > 0 ? "\(diffSeconds)s late" : "\(abs(diffSeconds))s early"
//                LogManager.shared.log(category: .taskScheduler, message: "Executing \(id) scheduled for \(scheduledTimeString) (\(diffInfo))")

                var updatedTask = task
                updatedTask.nextRun = .distantFuture
                tasks[id] = updatedTask

                DispatchQueue.main.async {
                    task.action()
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

private extension TaskID {
    var description: String {
        switch self {
        case .profile: return "profile"
        case .deviceStatus: return "deviceStatus"
        case .fetchBG: return "fetchBG"
        case .treatments: return "treatments"
        case .calendarWrite: return "calendarWrite"
        case .minAgoUpdate: return "minAgoUpdate"
        case .alarmCheck: return "alarmCheck"
        }
    }
}
