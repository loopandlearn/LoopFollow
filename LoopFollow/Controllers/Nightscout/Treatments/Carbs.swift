//
//  Carbs.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Carb Bolus Response Processor
    func processNSCarbs(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Carbs") }
        // because it's a small array, we're going to destroy and reload every time.
        carbData.removeAll()
        var lastFoundIndex = 0
        var lastFoundBolus = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var carbDate: String
            if currentEntry?["timestamp"] != nil {
                carbDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                carbDate = currentEntry?["created_at"] as! String
            } else {
                continue
            }
            
            
            let absorptionTime = currentEntry?["absorptionTime"] as? Int ?? 0
            
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(carbDate.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let dateString = dateFormatter.date(from: strippedZone) else { continue }
            var dateTimeStamp = dateString.timeIntervalSince1970
            
            guard let carbs = currentEntry?["carbs"] as? Double else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Null Carb entry")}
                continue
            }
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            var offset = -50
            if sgv.sgv < Double(topBG - 100) {
                let bolusTime = findNearestBolusbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: bolusData, startingIndex: lastFoundBolus)
                lastFoundBolus = bolusTime.foundIndex
                
                if bolusTime.offset {
                    offset = 70
                } else {
                    offset = 20
                }
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = carbGraphStruct(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv + Double(offset)), absorptionTime: absorptionTime)
                carbData.append(dot)
            }
        }
        
        if UserDefaultsRepository.graphCarbs.value {
            updateCarbGraph()
        }
    }
    
    func updateTodaysCarbsFromEntries(entries: [[String:AnyObject]]) {
        var totalCarbs: Double = 0.0
        
        let calendar = Calendar.current
        let now = Date()
        
        for entry in entries {
            var carbDate: String = ""
            
            if let timestamp = entry["timestamp"] as? String {
                carbDate = timestamp
            } else if let createdAt = entry["created_at"] as? String {
                carbDate = createdAt
            } else {
                print("Skipping entry with no timestamp or created_at")
                continue
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let date = dateFormatter.date(from: carbDate) else {
                print("Unable to parse date from: \(carbDate)")
                continue
            }
            
            if calendar.isDateInToday(date) {
                if let carbs = entry["carbs"] as? Double {
                    totalCarbs += carbs
                } else {
                    print("Carbs not found for entry")
                }
            }
        }
        
        let resultString = String(format: "%.0f", totalCarbs)
        tableData[10].value = resultString
        infoTable.reloadData()
    }
}
