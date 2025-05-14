//
//  Task.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-12.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {
    func scheduleAllTasks() {
        scheduleBGTask()
        scheduleProfileTask()
        scheduleDeviceStatusTask()
        scheduleTreatmentsTask()
        scheduleMinAgoTask()
        scheduleCalendarTask()
        scheduleAlarmTask()
    }
}
