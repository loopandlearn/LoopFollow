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
        // Because it's a small array, we're going to destroy and reload every time.
        carbData.removeAll()
        var lastFoundIndex = 0
        var lastFoundBolus = 0
        var lastFoundSmb = 0

        
        entries.reversed().forEach { currentEntry in
            var carbDate: String
            if currentEntry["timestamp"] != nil {
                carbDate = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                carbDate = currentEntry["created_at"] as! String
            } else {
                return
            }
            
            let absorptionTime = currentEntry["absorptionTime"] as? Int ?? 0
            
            let foodType = currentEntry["foodType"]
            
            guard let parsedDate = NightscoutUtils.parseDate(carbDate),
                  let carbs = currentEntry["carbs"] as? Double else { return }
            
            let dateTimeStamp = parsedDate.timeIntervalSince1970
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            var offset = -50
            if sgv.sgv < Double(topBG - 100) {
                let bolusTime = findNearestBolusbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: bolusData, startingIndex: lastFoundBolus)
                lastFoundBolus = bolusTime.foundIndex
                
                offset = bolusTime.offset ? 70 : 20
            }
            
            if sgv.sgv < Double(topBG - 100) {
                let smbTime = findNearestSmbbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: smbData, startingIndex: lastFoundSmb)
                lastFoundSmb = smbTime.foundIndex
                
                offset = smbTime.offset ? 70 : 20
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (3600 * UserDefaultsRepository.predictionToLoad.value)) {
                // Make the dot
                let dot = carbGraphStruct(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv + Double(offset)), absorptionTime: absorptionTime, foodType: foodType as? String)
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
            
            guard let date = NightscoutUtils.parseDate(carbDate) else {
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
        
        let resultString = String(format: "%.0f", totalCarbs) + " g"
        tableData[10].value = resultString
        infoTable.reloadData()
    }
}
