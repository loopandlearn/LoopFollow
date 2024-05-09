//
//  Smb.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Meal SMB Response Processor
    func processNSSmb(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: SMB") }
        // because it's a small array, we're going to destroy and reload every time.
        smbData.removeAll()
        var lastFoundIndex = 0
        
        entries.reversed().forEach { currentEntry in
            var smbDate: String
            if currentEntry["timestamp"] != nil {
                smbDate = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                smbDate = currentEntry["created_at"] as! String
            } else {
                return
            }
            
            guard let parsedDate = NightscoutUtils.parseDate(smbDate),
                  let smb = currentEntry["insulin"] as? Double else { return }
            
            let dateTimeStamp = parsedDate.timeIntervalSince1970
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = smbGraphStruct(value: smb, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
                smbData.append(dot)
            }
        }
        
        if UserDefaultsRepository.graphSmb.value {
            updateSmbGraph()
        }
    }
}
