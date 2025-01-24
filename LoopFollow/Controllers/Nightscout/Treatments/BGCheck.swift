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
        //if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG Check") }
        bgCheckData.removeAll()
        
        entries.reversed().forEach { currentEntry in
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            
            guard let parsedDate = NightscoutUtils.parseDate(dateStr),
                  let glucose = currentEntry["glucose"] as? Double else {
                //if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Non-Double Glucose entry") }
                return
            }
            
            let units = currentEntry["units"] as? String ?? "mg/dl"
            let convertedGlucose: Double = units == "mmol" ? glucose * GlucoseConversion.mmolToMgDl : glucose

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                let dot = ShareGlucoseData(sgv: Int(convertedGlucose.rounded()), date: Double(dateTimeStamp), direction: "")
                bgCheckData.append(dot)
            }
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateBGCheckGraph()
        }
    }
}

