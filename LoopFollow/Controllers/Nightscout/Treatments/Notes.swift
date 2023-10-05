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
            
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            guard let thisNote = currentEntry?["notes"] as? String else { continue }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.noteStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv), note: thisNote)
                noteGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateNotes()
        }
    }
}
