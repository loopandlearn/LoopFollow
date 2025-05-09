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
                bgReadings: self.bgData
                    .suffix(24)
                    .map { GlucoseValue(sgv: $0.sgv, date: Date(timeIntervalSince1970: $0.date)) }, /// These are oldest .. newest
                predictionData: self.predictionData
                    .prefix(12)
                    .map { GlucoseValue(sgv: $0.sgv, date: Date(timeIntervalSince1970: $0.date)) }, /// These are oldest .. newest, Predictions not currently available for Trio
                expireDate: Storage.shared.expirationDate.value
            )

            let finalAlarmData: AlarmData
            if Observable.shared.debug.value {
                self.saveLatestAlarmDataToFile(alarmData)
                finalAlarmData = self.loadTestAlarmData() ?? alarmData
            } else {
                finalAlarmData = alarmData
            }

            LogManager.shared.log(category: .alarm, message: "Checking alarms based on \(finalAlarmData)", isDebug: true)

            AlarmManager.shared.checkAlarms(data: finalAlarmData)

            TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(60))
        }
    }

    func saveLatestAlarmDataToFile(_ alarmData: AlarmData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(alarmData)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("latestAlarmData.json")
            try data.write(to: url)
        } catch {
            LogManager.shared.log(category: .alarm, message: "Failed to save latest AlarmData: \(error)", isDebug: true)
        }
    }

    func loadTestAlarmData() -> AlarmData? {
        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("testAlarmData.json")

        if fileManager.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let alarmData = try decoder.decode(AlarmData.self, from: data)
                LogManager.shared.log(category: .alarm, message: "Loaded test AlarmData from \(url.path)", isDebug: true)
                return alarmData
            } catch {
                LogManager.shared.log(category: .alarm, message: "Failed to load test AlarmData: \(error)", isDebug: true)
            }
        }
        return nil
    }
}
