//
//  AlarmTask.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-12.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
//TODO: Nu körs ju alarm var 60 sekund... men man vill nog ha det direkt efter bg-värdet kommer in etc.
//TODO: Men ändå kanske inte för nära ett tidigare alarm, men det kanske vi inte hanterar här....
extension MainViewController {
    func scheduleAlarmTask(initialDelay: TimeInterval = 60) {
        let firstRun = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .alarmCheck, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.alarmTaskAction()
        }
    }

    func alarmTaskAction() {
        DispatchQueue.main.async {
            //TODO: Fyll på med mer alarmData
            //TODO: gör det möjligt att köra med fejkad data.
            let alarmData = AlarmData(
                expireDate: Storage.shared.expirationDate.value
            )

            LogManager.shared.log(category: .alarm, message: "Checking alarms based on \(alarmData)", isDebug: true)

            AlarmManager.shared.checkAlarms(data: alarmData)

            TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(60))
        }
    }
}
