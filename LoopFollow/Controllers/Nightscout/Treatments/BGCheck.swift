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
    // NS BG Check Response Processor
    func processNSBGCheck(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG Check") }
        // because it's a small array, we're going to destroy and reload every time.
        bgCheckData.removeAll()
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
            let dateTimeStamp = dateString!.timeIntervalSince1970
            
            guard let sgv = currentEntry?["glucose"] as? Int else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Non-Int Glucose entry")}
                continue
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                //let dot = ShareGlucoseData(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                let dot = ShareGlucoseData(sgv: sgv, date: Double(dateTimeStamp), direction: "")
                bgCheckData.append(dot)
            }
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateBGCheckGraph()
        }
    }
}
