//
//  SensorStart.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-04.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    func processSage(entries: [sageData]) {
        if !entries.isEmpty {
            updateSage(data: entries)
        } else if let sage = currentSage {
            updateSage(data: [sage])
        } else {
            webLoadNSSage()
        }
    }
    
    // NS Sensor Change Response Processor
    func processSensorChange(entries: [sageData]) {
        sensorChangeGraphData.removeAll()
        var lastFoundIndex = 0
        for entry in entries {
            let date = entry.created_at
            
            if let parsedDate = NightscoutUtils.parseDate(date) {
                let dateTimeStamp = parsedDate.timeIntervalSince1970
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex
                
                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                    sensorChangeGraphData.append(dot)
                }
            } else {
                print("Failed to parse date")
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateSensorChange()
        }
    }
}
