// LoopFollow
// DeviceStatusTask.swift

import Foundation

extension MainViewController {
    func scheduleDeviceStatusTask(initialDelay: TimeInterval = 4) {
        let startTime = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .deviceStatus, nextRun: startTime) { [weak self] in
            guard let self = self else { return }
            self.deviceStatusAction()
        }
    }

    func deviceStatusAction() {
        // If no NS config, we wait 60s before trying again:
        guard IsNightscoutEnabled() else {
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date().addingTimeInterval(60))
            return
        }

        webLoadNSDeviceStatus()
    }
}
