// LoopFollow
// NightscoutSocketDataHandler.swift

import Foundation

extension MainViewController {
    func setupNightscoutSocket() {
        NightscoutSocketManager.shared.onDataUpdate = { [weak self] data in
            self?.handleSocketDataUpdate(data)
        }
        NightscoutSocketManager.shared.connectIfNeeded()
    }

    func handleSocketDataUpdate(_ data: [String: Any]) {
        let isDelta = data["delta"] as? Bool ?? false

        if !isDelta {
            // Full data on initial connect — trigger all fetches
            LogManager.shared.log(category: .websocket, message: "Full data received, triggering all fetches")
            TaskScheduler.shared.rescheduleTask(id: .fetchBG, to: Date())
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date())
            TaskScheduler.shared.rescheduleTask(id: .treatments, to: Date())
            TaskScheduler.shared.rescheduleTask(id: .profile, to: Date())
            return
        }

        // Selective: only fetch data types present in the delta
        var triggered: [String] = []

        if data["sgvs"] != nil || data["mbgs"] != nil {
            TaskScheduler.shared.rescheduleTask(id: .fetchBG, to: Date())
            triggered.append("BG")
        }

        if data["devicestatus"] != nil {
            TaskScheduler.shared.rescheduleTask(id: .deviceStatus, to: Date())
            triggered.append("DeviceStatus")
        }

        if data["treatments"] != nil {
            TaskScheduler.shared.rescheduleTask(id: .treatments, to: Date())
            triggered.append("Treatments")
        }

        if data["profiles"] != nil {
            TaskScheduler.shared.rescheduleTask(id: .profile, to: Date())
            triggered.append("Profile")
        }

        if !triggered.isEmpty {
            LogManager.shared.log(category: .websocket, message: "Delta triggered: \(triggered.joined(separator: ", "))", isDebug: true)
        }
    }
}
