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
        bgCheckData.removeAll()
        
        entries.reversed().forEach { currentEntry in
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            
            guard let parsedDate = NightscoutUtils.parseDate(dateStr),
                  let glucose = currentEntry["glucose"] as? Double else {
                if UserDefaultsRepository.debugLog.value {
                    self.writeDebugLog(value: "ERROR: Non-Double Glucose entry")
                }
                return
            }

            let multipliedGlucose = glucose * 18 // Multiply the glucose value by 2 (change the multiplier as needed)

            let sgv = Int(multipliedGlucose) // Convert the multiplied glucose value to an integer

            let dateTimeStamp = parsedDate.timeIntervalSince1970
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
