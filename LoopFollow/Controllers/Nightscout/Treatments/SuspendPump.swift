//
//  SuspendPump.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Suspend Pump Response Processor
    func processSuspendPump(entries: [[String:AnyObject]]) {
        suspendGraphData.removeAll()
        
        var lastFoundIndex = 0
        
        entries.reversed().forEach { currentEntry in
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { return }
            
            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else {
                return
            }
            
            let dateTimeStamp = parsedDate.timeIntervalSince1970
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                suspendGraphData.append(dot)
            }
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateSuspendGraph()
        }
    }
}
