// LoopFollow
// Task.swift
// Created by Jonas Björkert.

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
