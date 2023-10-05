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
        // because it's a small array, we're going to destroy and reload every time.
        overrideGraphData.removeAll()
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            var dateTimeStamp = dateString!.timeIntervalSince1970
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }
            
            var multiplier: Double = 1.0
            if currentEntry?["insulinNeedsScaleFactor"] != nil {
                multiplier = currentEntry?["insulinNeedsScaleFactor"] as! Double
            }
            var duration: Double = 5.0
            if let durationType = currentEntry?["durationType"] as? String {
                if i == entries.count - 1 {
                    duration = dateTimeUtils.getNowTimeIntervalUTC() - dateTimeStamp + (60 * 60)
                }
            } else {
                duration = (currentEntry?["duration"] as? Double)!
                duration = duration * 60
            }
            
            // Skip overrides that aren't 5 minutes long. This prevents overlapping that causes bars to not display.
            if duration < 300 { continue }
            
            guard let enteredBy = currentEntry?["enteredBy"] as? String else { continue }
            guard let reason = currentEntry?["reason"] as? String else { continue }
            
            var range: [Int] = []
            if let ranges = currentEntry?["correctionRange"] as? [Int] {
                if ranges.count == 2 {
                    guard let low = ranges[0] as? Int else { continue }
                    guard let high = ranges[1] as? Int else { continue }
                    range.append(low)
                    range.append(high)
                }
                
            } else {
                let low = currentEntry?["targetBottom"] as? Int
                let high = currentEntry?["targetTop"] as? Int
                
                if (low == nil && high != nil) || (low != nil && high == nil) {
                    continue
                }
                
                if let l = low {
                    range.append(l)
                }
                
                if let h = high {
                    range.append(h)
                }
            }
            
            let endDate = dateTimeStamp + (duration)
            
            let dot = DataStructs.overrideStruct(insulNeedsScaleFactor: multiplier, date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: range, enteredBy: enteredBy, reason: reason, sgv: -20)
            overrideGraphData.append(dot)
            
            
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateOverrideGraph()
        }
        
    }
}
