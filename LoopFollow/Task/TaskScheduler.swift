//
//  TaskScheduler.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

enum TaskID: CaseIterable {
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
            LogManager.shared.log(category: .taskScheduler, message: "scheduleTask(\(id)): next run = \(timeString)", isDebug: true)

            self.tasks[id] = ScheduledTask(nextRun: nextRun, action: action)
            self.rescheduleTimer()
        }
    }

    func rescheduleTask(id: TaskID, to newRunDate: Date) {
        let timeString = self.formatTime(newRunDate)
        //LogManager.shared.log(category: .taskScheduler, message: "Reschedule Task \(id): next run = \(timeString)", isDebug: true)

        queue.async {
            guard var existingTask = self.tasks[id] else {
                return
            }
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

    /// Updated signature to include info about who called us, and which task triggered it (if any).
    private func rescheduleTimer() {
        // Invalidate any existing timer
        currentTimer?.invalidate()
        currentTimer = nil

        guard let (_, earliestTask) = tasks.min(by: { $0.value.nextRun < $1.value.nextRun }) else {
            LogManager.shared.log(category: .taskScheduler, message: "No tasks, no timer scheduled.")
            return
        }

        let interval = earliestTask.nextRun.timeIntervalSinceNow
        let safeInterval = max(interval, 0)

        // Comment out this block to simulate heartbeat execution only
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
        BackgroundAlertManager.shared.scheduleBackgroundAlert()

        let now = Date()
        let tasksToSkipAlarmCheck: Set<TaskID> = [.deviceStatus, .treatments, .fetchBG]

        for taskID in TaskID.allCases {
            guard let task = tasks[taskID], task.nextRun <= now else {
                continue
            }

            // Check if we should skip alarmCheck
            if taskID == .alarmCheck {
                let shouldSkip = tasksToSkipAlarmCheck.contains {
                    guard let checkTask = tasks[$0] else { return false }
                    return checkTask.nextRun <= now || checkTask.nextRun == .distantFuture
                }

                if shouldSkip {
                    //LogManager.shared.log(category: .taskScheduler, message: "Skipping alarmCheck because one of the specified tasks is due or set to distant future.")
                    continue
                }
            }

            var updatedTask = task
            updatedTask.nextRun = .distantFuture
            tasks[taskID] = updatedTask

            //LogManager.shared.log(category: .taskScheduler, message: "Executing task \(taskID)", isDebug: true)

            DispatchQueue.main.async {
                task.action()
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
