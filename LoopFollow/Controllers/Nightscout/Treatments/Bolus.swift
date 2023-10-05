//
//  Bolus.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Meal Bolus Response Processor
    func processNSBolus(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Bolus") }
        // because it's a small array, we're going to destroy and reload every time.
        bolusData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var bolusDate: String
            if currentEntry?["timestamp"] != nil {
                bolusDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                bolusDate = currentEntry?["created_at"] as! String
            } else {
                continue
            }
            
            // fix to remove millisecond (after period in timestamp) for FreeAPS users
            var strippedZone = String(bolusDate.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let dateString = dateFormatter.date(from: strippedZone) else { continue }
            let dateTimeStamp = dateString.timeIntervalSince1970
            
            guard let bolus = currentEntry?["insulin"] as? Double else { continue }
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
                bolusData.append(dot)
            }
        }
        
        if UserDefaultsRepository.graphBolus.value {
            updateBolusGraph()
        }
    }
}
