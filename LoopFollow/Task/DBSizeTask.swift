// LoopFollow
// DBSizeTask.swift

import Foundation

extension MainViewController {
    /// Nightscout recomputes the database size on every data load, but the value only moves
    /// by a few MiB per day, so a slow poll is enough.
    private static let dbSizeInterval: TimeInterval = 6 * 60 * 60

    func scheduleDBSizeTask(initialDelay: TimeInterval = 5) {
        let firstRun = Date().addingTimeInterval(initialDelay)

        TaskScheduler.shared.scheduleTask(id: .dbSize, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.dbSizeTaskAction()
        }
    }

    func dbSizeTaskAction() {
        guard IsNightscoutEnabled() else {
            TaskScheduler.shared.rescheduleTask(id: .dbSize, to: Date().addingTimeInterval(60))
            return
        }

        webLoadNSDBSize()

        TaskScheduler.shared.rescheduleTask(id: .dbSize, to: Date().addingTimeInterval(Self.dbSizeInterval))
    }
}
