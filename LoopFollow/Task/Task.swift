// LoopFollow
// Task.swift

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
