// LoopFollow
// Overrides.swift
// Created by Jonas Björkert on 2023-10-05.

import Foundation
import UIKit

extension MainViewController {
    // NS Override Response Processor
    func processNSOverrides(entries: [[String: AnyObject]]) {
        overrideGraphData.removeAll()
        var activeOverrideNote: String?

        let now = Date().timeIntervalSince1970
        let predictionLoadHours = UserDefaultsRepository.predictionToLoad.value
        let predictionLoadSeconds = predictionLoadHours * 3600
        let maxEndDate = now + predictionLoadSeconds

        for (index, currentEntry) in entries.reversed().enumerated() {
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { continue }
            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else { continue }

            var dateTimeStamp = parsedDate.timeIntervalSince1970
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }

            let multiplier = currentEntry["insulinNeedsScaleFactor"] as? Double ?? 1.0

            var duration = 5.0
            if let _ = currentEntry["durationType"] as? String, index == entries.count - 1 {
                duration = dateTimeUtils.getNowTimeIntervalUTC() - dateTimeStamp + (60 * 60)
            } else {
                duration = (currentEntry["duration"] as? Double ?? 5.0) * 60
            }

            if duration < 300 { continue }

            let reason = currentEntry["reason"] as? String ?? ""

            guard let enteredBy = currentEntry["enteredBy"] as? String else {
                continue
            }

            var range: [Int] = []
            if let ranges = currentEntry["correctionRange"] as? [Int], ranges.count == 2 {
                range = ranges
            } else {
                let low = currentEntry["targetBottom"] as? Int
                let high = currentEntry["targetTop"] as? Int
                if (low == nil && high != nil) || (low != nil && high == nil) { continue }
                range = [low ?? 0, high ?? 0]
            }

            // Limit displayed override duration to 'Hours of Prediction' after current time
            var endDate = dateTimeStamp + duration
            if endDate > maxEndDate {
                endDate = maxEndDate
                duration = endDate - dateTimeStamp
            }

            if dateTimeStamp <= now, now < endDate {
                activeOverrideNote = currentEntry["notes"] as? String ?? currentEntry["reason"] as? String
            }

            let dot = DataStructs.overrideStruct(insulNeedsScaleFactor: multiplier, date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: range, enteredBy: enteredBy, reason: reason, sgv: -20)
            overrideGraphData.append(dot)
        }

        Observable.shared.override.value = activeOverrideNote

        if ObservableUserDefaults.shared.device.value == "Trio" {
            if let note = activeOverrideNote {
                infoManager.updateInfoData(type: .override, value: note)
            } else {
                infoManager.clearInfoData(type: .override)
            }
        }

        if UserDefaultsRepository.graphOtherTreatments.value {
            updateOverrideGraph()
        }
    }
}
