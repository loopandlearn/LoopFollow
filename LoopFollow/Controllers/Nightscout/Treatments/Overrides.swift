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
        
        entries.reversed().enumerated().forEach { (index, currentEntry) in
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else { return }
            
            var dateTimeStamp = parsedDate.timeIntervalSince1970
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }
            
            let multiplier = currentEntry["insulinNeedsScaleFactor"] as? Double ?? 1.0
            
            var duration: Double = 5.0
            if let _ = currentEntry["durationType"] as? String, index == entries.count - 1 {
                duration = dateTimeUtils.getNowTimeIntervalUTC() - dateTimeStamp + (60 * 60)
            } else {
                duration = (currentEntry["duration"] as? Double ?? 5.0) * 60
            }
            
            if duration < 300 { return }
            
            guard let enteredBy = currentEntry["enteredBy"] as? String, let reason = currentEntry["reason"] as? String else { return }
            
            var range: [Int] = []
            if let ranges = currentEntry["correctionRange"] as? [Int], ranges.count == 2 {
                range = ranges
            } else {
                let low = currentEntry["targetBottom"] as? Int
                let high = currentEntry["targetTop"] as? Int
                if (low == nil && high != nil) || (low != nil && high == nil) { return }
                range = [low ?? 0, high ?? 0]
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
