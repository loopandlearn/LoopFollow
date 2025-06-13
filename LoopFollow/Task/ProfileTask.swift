// LoopFollow
// ProfileTask.swift
// Created by Jonas Björkert on 2025-01-13.

import Foundation

extension MainViewController {
    func scheduleProfileTask(initialDelay: TimeInterval = 3) {
        let firstRun = Date().addingTimeInterval(initialDelay)

        TaskScheduler.shared.scheduleTask(id: .profile, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.profileTaskAction()
        }
    }

    func profileTaskAction() {
        guard IsNightscoutEnabled() else {
            TaskScheduler.shared.rescheduleTask(id: .profile, to: Date().addingTimeInterval(60))
            return
        }

        webLoadNSProfile()

        TaskScheduler.shared.rescheduleTask(id: .profile, to: Date().addingTimeInterval(10 * 60))
    }
}
