//
//  CarbsToday.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-04.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

extension MainViewController {
    // NS Override Response Processor
    func processNSOverrides(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Overrides") }
        overrideGraphData.removeAll()
        
        entries.reversed().forEach { currentEntry in
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            
            guard let parsedDate = NightscoutUtils.parseDate(dateStr),
                  let enteredBy = currentEntry["enteredBy"] as? String,
                  let reason = currentEntry["reason"] as? String else { return }
            
            var dateTimeStamp = parsedDate.timeIntervalSince1970
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }
            
            let multiplier = currentEntry["insulinNeedsScaleFactor"] as? Double ?? 1.0
            var duration = currentEntry["duration"] as? Double ?? 5.0
            duration *= 60  // Convert duration to seconds
            
            if duration < 300 { return }
            
            var range: [Int] = []
            if let ranges = currentEntry["correctionRange"] as? [Int], ranges.count == 2 {
                range = ranges
            } else {
                if let low = currentEntry["targetBottom"] as? Int, let high = currentEntry["targetTop"] as? Int {
                    range = [low, high]
                } else { return }
            }
            
            let endDate = dateTimeStamp + duration
            let dot = DataStructs.overrideStruct(insulNeedsScaleFactor: multiplier, date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: range, enteredBy: enteredBy, reason: reason, sgv: -20)
            overrideGraphData.append(dot)
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateOverrideGraph()
        }
    }
}
