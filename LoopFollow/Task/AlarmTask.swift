//
//  AlarmTask.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-12.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {
    func scheduleAlarmTask(initialDelay: TimeInterval = 30) {
        let firstRun = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .alarmCheck, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.alarmTaskAction()
        }
    }

    func alarmTaskAction() {
        DispatchQueue.main.async {
            let alarmData = AlarmData(
                expireDate: Storage.shared.expirationDate.value
            )

            LogManager.shared.log(category: .alarm, message: "Checking alarms based on \(alarmData)", isDebug: true)

            AlarmManager.shared.checkAlarms(data: alarmData)
            /*
            if self.bgData.count > 0 {
                self.checkAlarms(bgs: self.bgData)
            }
            if self.overrideGraphData.count > 0 {
                self.checkOverrideAlarms()
            }
            if self.tempTargetGraphData.count > 0 {
                self.checkTempTargetAlarms()
            }*/

            TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(30))
        }
    }
}
