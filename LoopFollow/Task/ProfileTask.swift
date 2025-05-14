//
//  ProfileTask.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-11.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

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
