//
//  Basals.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String:AnyObject]]) {
        self.clearLastInfoData(index: 2)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Basal") }
        // due to temp basal durations, we're going to destroy the array and load everything each cycle for the time being.
        basalData.removeAll()
        
        var lastEndDot = 0.0
        
        var tempArray = entries
        tempArray.reverse()
        for i in 0..<tempArray.count {
            let currentEntry = tempArray[i] as [String : AnyObject]?
            var basalDate: String
            if currentEntry?["timestamp"] != nil {
                basalDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                basalDate = currentEntry?["created_at"] as! String
            } else {
                continue
            }
            var strippedZone = String(basalDate.dropLast())
            strippedZone = strippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let dateString = dateFormatter.date(from: strippedZone) else { continue }
            let dateTimeStamp = dateString.timeIntervalSince1970
            guard let basalRate = currentEntry?["absolute"] as? Double else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Null Basal entry")}
                continue
            }
            
            let midnightTime = dateTimeUtils.getTimeIntervalMidnightToday()
            // Setting end dots
            var duration = 0.0
            do {
                duration = try currentEntry?["duration"] as! Double
            } catch {
                print("No Duration Found")
            }
            
            // This adds scheduled basal wherever there is a break between temps. can't check the prior ending on the first item. it is 24 hours old, so it isn't important for display anyway
            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String : AnyObject]?
                var priorBasalDate: String
                if priorEntry?["timestamp"] != nil {
                    priorBasalDate = priorEntry?["timestamp"] as! String
                } else if currentEntry?["created_at"] != nil {
                    priorBasalDate = priorEntry?["created_at"] as! String
                } else {
                    continue
                }
                var priorStrippedZone = String(priorBasalDate.dropLast())
                priorStrippedZone = priorStrippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                let priorDateFormatter = DateFormatter()
                priorDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                priorDateFormatter.locale = Locale(identifier: "en_US")
                priorDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                guard let priorDateString = dateFormatter.date(from: priorStrippedZone) else { continue }
                let priorDateTimeStamp = priorDateString.timeIntervalSince1970
                let priorDuration = priorEntry?["duration"] as? Double ?? 0.0
                // if difference between time stamps is greater than the duration of the last entry, there is a gap. Give a 15 second leeway on the timestamp
                if Double( dateTimeStamp - priorDateTimeStamp ) > Double( (priorDuration * 60) + 15 ) {
                    
                    var scheduled = 0.0
                    var midGap = false
                    var midGapTime: TimeInterval = 0
                    var midGapValue: Double = 0
                    // cycle through basal profiles.
                    // TODO figure out how to deal with profile changes that happen mid-gap
                    for b in 0..<self.basalScheduleData.count {
                        
                        if (priorDateTimeStamp + (priorDuration * 60)) >= basalScheduleData[b].date {
                            scheduled = basalScheduleData[b].basalRate
                            
                            // deal with mid-gap scheduled basal change
                            // don't do it on the last scheudled basal entry
                            if b < self.basalScheduleData.count - 1 {
                                if dateTimeStamp > self.basalScheduleData[b + 1].date {
                                    // midGap = true
                                    // TODO: finish this to handle mid-gap items without crashing from overlapping entries
                                    midGapTime = self.basalScheduleData[b + 1].date
                                    midGapValue = self.basalScheduleData[b + 1].basalRate
                                }
                            }
                            
                        }
                        
                    }
                    
                    // Make the starting dot at the last ending dot
                    let startDot = basalGraphStruct(basalRate: scheduled, date: Double(priorDateTimeStamp + (priorDuration * 60)))
                    basalData.append(startDot)
                    
                    
                    if midGap {
                        // Make the ending dot at the new scheduled basal
                        let endDot1 = basalGraphStruct(basalRate: scheduled, date: Double(midGapTime))
                        basalData.append(endDot1)
                        // Make the starting dot at the scheduled Time
                        let startDot2 = basalGraphStruct(basalRate: midGapValue, date: Double(midGapTime))
                        basalData.append(startDot2)
                        // Make the ending dot at the new basal value
                        let endDot2 = basalGraphStruct(basalRate: midGapValue, date: Double(dateTimeStamp))
                        basalData.append(endDot2)
                        
                    } else {
                        // Make the ending dot at the new starting dot
                        let endDot = basalGraphStruct(basalRate: scheduled, date: Double(dateTimeStamp))
                        basalData.append(endDot)
                    }
                    
                    
                }
            }
            
            // Make the starting dot
            let startDot = basalGraphStruct(basalRate: basalRate, date: Double(dateTimeStamp))
            basalData.append(startDot)
            
            // Make the ending dot
            // If it's the last one and has no duration, extend it for 30 minutes past the start. Otherwise set ending at duration
            // duration is already set to 0 if there is no duration set on it.
            //if i == tempArray.count - 1 && dateTimeStamp + duration <= dateTimeUtils.getNowTimeIntervalUTC() {
            if i == tempArray.count - 1 && duration == 0.0 {
                lastEndDot = dateTimeStamp + (30 * 60)
                latestBasal = String(format:"%.2f", basalRate)
            } else {
                lastEndDot = dateTimeStamp + (duration * 60)
                latestBasal = String(format:"%.2f", basalRate)
            }
            
            // Double check for overlaps of incorrectly ended TBRs and sent it to end when the next one starts if it finds a discrepancy
            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String : AnyObject]?
                var nextBasalDate: String
                if nextEntry?["timestamp"] != nil {
                    nextBasalDate = nextEntry?["timestamp"] as! String
                } else if currentEntry?["created_at"] != nil {
                    nextBasalDate = nextEntry?["created_at"] as! String
                } else {
                    continue
                }
                var nextStrippedZone = String(nextBasalDate.dropLast())
                nextStrippedZone = nextStrippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                let nextDateFormatter = DateFormatter()
                nextDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                nextDateFormatter.locale = Locale(identifier: "en_US")
                nextDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                guard let nextDateString = dateFormatter.date(from: nextStrippedZone) else { continue }
                let nextDateTimeStamp = nextDateString.timeIntervalSince1970
                if nextDateTimeStamp < (dateTimeStamp + (duration * 60)) {
                    lastEndDot = nextDateTimeStamp
                }
            }
            
            let endDot = basalGraphStruct(basalRate: basalRate, date: Double(lastEndDot))
            basalData.append(endDot)
            
            
        }
        
        // If last  basal was prior to right now, we need to create one last scheduled entry
        if lastEndDot <= dateTimeUtils.getNowTimeIntervalUTC() {
            var scheduled = 0.0
            // cycle through basal profiles.
            // TODO figure out how to deal with profile changes that happen mid-gap
            for b in 0..<self.basalProfile.count {
                let scheduleTimeYesterday = self.basalProfile[b].timeAsSeconds + dateTimeUtils.getTimeIntervalMidnightYesterday()
                let scheduleTimeToday = self.basalProfile[b].timeAsSeconds + dateTimeUtils.getTimeIntervalMidnightToday()
                // check the prior temp ending to the profile seconds from midnight
                if lastEndDot >= scheduleTimeToday {
                    scheduled = basalProfile[b].value
                }
            }
            
            latestBasal = String(format:"%.2f", scheduled) + " E/h"
            // Make the starting dot at the last ending dot
            let startDot = basalGraphStruct(basalRate: scheduled, date: Double(lastEndDot))
            basalData.append(startDot)
            
            // Make the ending dot 10 minutes after now
            let endDot = basalGraphStruct(basalRate: scheduled, date: Double(Date().timeIntervalSince1970 + (60 * 10)))
            basalData.append(endDot)
            
        }
        tableData[2].value = latestBasal
        infoTable.reloadData()
        if UserDefaultsRepository.graphBasal.value {
            updateBasalGraph()
        }
        infoTable.reloadData()
    }
}
