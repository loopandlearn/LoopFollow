// LoopFollow
// TemporaryTarget.swift
// Created by Jonas Björkert on 2024-07-28.

import Foundation
import HealthKit
import UIKit

extension MainViewController {
    // NS Temporary Target Response Processor
    func processNSTemporaryTarget(entries: [[String: AnyObject]]) {
        tempTargetGraphData.removeAll()
        var activeTempTarget: Int?

        for (index, currentEntry) in entries.reversed().enumerated() {
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { continue }
            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else { continue }

            var dateTimeStamp = parsedDate.timeIntervalSince1970
            let graphHours = 24 * Storage.shared.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }

            let duration: Double = (currentEntry["duration"] as? Double ?? 5.0) * 60

            // If duration is 0, this marks the end of the last temp target
            if duration == 0 {
                if let activeIndex = tempTargetGraphData.lastIndex(where: { $0.endDate > dateTimeStamp }) {
                    tempTargetGraphData[activeIndex].endDate = dateTimeStamp
                    activeTempTarget = nil
                }
                continue
            }

            if duration < 300 {
                continue
            }

            let reason = currentEntry["reason"] as? String ?? ""

            guard let enteredBy = currentEntry["enteredBy"] as? String else {
                continue
            }

            let low = currentEntry["targetBottom"] as? Double
            let high = currentEntry["targetTop"] as? Double
            let targetValue = low ?? high

            if targetValue == nil {
                continue
            }

            let endDate = dateTimeStamp + duration

            let dot = DataStructs.tempTargetStruct(date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: [Int(targetValue!)], enteredBy: enteredBy, reason: reason)
            tempTargetGraphData.append(dot)

            // Set activeTempTarget only if it is still active
            let currentTime = Date().timeIntervalSince1970
            if currentTime < endDate {
                activeTempTarget = Int(targetValue!)
            }
        }

        if UserDefaultsRepository.graphOtherTreatments.value {
            updateTempTargetGraph()
            updateChartRenderers()
        }

        if let target = activeTempTarget {
            let unit = HKUnit.milligramsPerDeciliter
            let quantity = HKQuantity(unit: unit, doubleValue: Double(target))
            Observable.shared.tempTarget.value = quantity
        } else {
            Observable.shared.tempTarget.value = nil
        }
    }
}
