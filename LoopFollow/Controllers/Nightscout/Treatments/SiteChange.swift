//
//  SiteChange.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-06.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    func processCage(entries: [cageData]) {
        if !entries.isEmpty {
            updateCage(data: entries)
        } else if let cage = currentCage {
            updateCage(data: [cage])
        } else {
            webLoadNSCage()
        }
    }
    
    // NS Pump Change Response Processor
    func processPumpChange(entries: [cageData]) {
        pumpChangeGraphData.removeAll()
        var lastFoundIndex = 0
        for entry in entries {
            let date = entry.created_at
            
            if let parsedDate = NightscoutUtils.parseDate(date) {
                let dateTimeStamp = parsedDate.timeIntervalSince1970
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex
                
                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                    pumpChangeGraphData.append(dot)
                }
            } else {
                print("Failed to parse date")
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
            updatePumpChange()
        }
    }
}
