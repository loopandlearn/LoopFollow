// LoopFollow
// CalendarTask.swift
// Created by Jonas Björkert on 2025-01-13.

import Foundation

extension MainViewController {
    func scheduleCalendarTask(initialDelay: TimeInterval = 15) {
        let startTime = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .calendarWrite, nextRun: startTime) { [weak self] in
            guard let self = self else { return }
            self.calendarTaskAction()
        }
    }

    func calendarTaskAction() {
        if UserDefaultsRepository.writeCalendarEvent.value,
           !UserDefaultsRepository.calendarIdentifier.value.isEmpty
        {
            writeCalendar()
        }

        TaskScheduler.shared.rescheduleTask(id: .calendarWrite, to: Date().addingTimeInterval(30))
    }
}
