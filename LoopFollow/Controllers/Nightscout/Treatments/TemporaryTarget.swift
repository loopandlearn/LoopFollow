//
//  TemporaryTarget.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-26.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import HealthKit

extension MainViewController {
    // NS Temporary Target Response Processor
    func processNSTemporaryTarget(entries: [[String: AnyObject]]) {
        overrideGraphData.removeAll()
        var activeTempTarget: Int? = nil

        entries.reversed().enumerated().forEach { (index, currentEntry) in
            print("\(currentEntry)")
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else { return }

            var dateTimeStamp = parsedDate.timeIntervalSince1970
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }

            var duration: Double = 5.0
            duration = (currentEntry["duration"] as? Double ?? 5.0) * 60

            // If duration is 0, this marks the end of the last temp target
            if duration == 0 {
                // Check for an active temporary target
                if let activeIndex = overrideGraphData.lastIndex(where: { $0.endDate > dateTimeStamp }) {
                    // Update the end date of the active temporary target
                    overrideGraphData[activeIndex].endDate = dateTimeStamp
                    activeTempTarget = nil
                }
                return
            }

            // Ignore very short durations
            if duration < 300 { return }

            guard let enteredBy = currentEntry["enteredBy"] as? String, let reason = currentEntry["reason"] as? String else { return }

            var range: [Int] = []
            let low = currentEntry["targetBottom"] as? Int
            let high = currentEntry["targetTop"] as? Int
            if (low == nil && high != nil) || (low != nil && high == nil) { return }
            range = [low ?? 0, high ?? 0]

            let endDate = dateTimeStamp + duration

            let dot = DataStructs.overrideStruct(insulNeedsScaleFactor: 1.0, date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: range, enteredBy: enteredBy, reason: reason, sgv: -20)
            overrideGraphData.append(dot)

            // Set activeTempTarget only if it is still active
            if Date().timeIntervalSince1970 < endDate {
                activeTempTarget = low
            }
        }

        if UserDefaultsRepository.graphOtherTreatments.value {
            updateOverrideGraph()
        }

        if let target = activeTempTarget {
            let unit = HKUnit.milligramsPerDeciliter
            let quantity = HKQuantity(unit: unit, doubleValue: Double(target))
            Observable.shared.tempTarget.value = quantity
        } else {
            Observable.shared.tempTarget.value = nil
        }

        let isActiveTempTarget = activeTempTarget != nil
        print("Is there an active temporary target? \(isActiveTempTarget)")
    }
}
