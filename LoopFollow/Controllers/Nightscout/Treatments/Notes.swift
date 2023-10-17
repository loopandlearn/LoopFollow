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
    // NS Note Response Processor
    func processNotes(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Notes") }
        // because it's a small array, we're going to destroy and reload every time.
        noteGraphData.removeAll()
        var lastFoundIndex = 0
        
        entries.reversed().forEach { currentEntry in
            guard let currentEntry = currentEntry as? [String: AnyObject] else { return }
            
            var date: String
            if currentEntry["timestamp"] != nil {
                date = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                date = currentEntry["created_at"] as! String
            } else {
                return
            }
            
            if let parsedDate = NightscoutUtils.parseDate(date) {
                let dateTimeStamp = parsedDate.timeIntervalSince1970
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex
                
                guard let thisNote = currentEntry["notes"] as? String else { return }
                
                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    let dot = DataStructs.noteStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv), note: thisNote)
                    noteGraphData.append(dot)
                }
            } else {
                print("Failed to parse date")
            }
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateNotes()
        }
    }
}
