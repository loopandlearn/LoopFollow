//
//  SensorStart.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-04.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Sensor Start Response Processor
    func processSensorStart(entries: [sageData]) {
        sensorStartGraphData.removeAll()
        var lastFoundIndex = 0
        for entry in entries {
            let date = entry.created_at
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970
            
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                sensorStartGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateSensorStart()
        }
    }
}
