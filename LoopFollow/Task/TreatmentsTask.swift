// LoopFollow
// TreatmentsTask.swift
// Created by Jonas Björkert on 2025-01-13.

import Foundation

extension MainViewController {
    func scheduleTreatmentsTask(initialDelay: TimeInterval = 5) {
        let firstRun = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .treatments, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.treatmentsTaskAction()
        }
    }

    func treatmentsTaskAction() {
        // If Nightscout not enabled, wait 60s and try again
        guard IsNightscoutEnabled(), Storage.shared.downloadTreatments.value else {
            TaskScheduler.shared.rescheduleTask(id: .treatments, to: Date().addingTimeInterval(60))
            return
        }

        WebLoadNSTreatments()

        TaskScheduler.shared.rescheduleTask(id: .treatments, to: Date().addingTimeInterval(2 * 60))
    }
}
