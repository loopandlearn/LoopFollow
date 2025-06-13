// LoopFollow
// Task.swift
// Created by Jonas Björkert on 2025-01-13.

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
