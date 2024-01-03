//
//  CAge.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
extension MainViewController {
    // NS Cage Web Call
    func webLoadNSCage() {
        let currentTimeString = dateTimeUtils.getCurrentDateTimeString()
        
        let parameters: [String: String] = [
            "find[eventType]": NightscoutUtils.EventType.cage.rawValue,
            "find[created_at][$lte]": currentTimeString,
            "count": "1"
        ]
        
        NightscoutUtils.executeRequest(eventType: .cage, parameters: parameters) { (result: Result<[cageData], Error>) in
            switch result {
            case .success(let data):
                self.updateCage(data: data)
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // NS Cage Response Processor
    func updateCage(data: [cageData]) {
        self.clearLastInfoData(index: 7)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: CAGE") }
        if data.count == 0 {
            return
        }
        
        currentCage = data[0]
        let lastCageString = data[0].created_at
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertCageInsertTime.value = formatter.date(from: (lastCageString))?.timeIntervalSince1970 as! TimeInterval
        if let cageTime = formatter.date(from: (lastCageString))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - cageTime
            //let days = 24 * 60 * 60
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour ] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale

            // Set maximumUnitCount to 0 to include all available units
            formatter.maximumUnitCount = 0
            
            if let formattedDuration = formatter.string(from: secondsAgo) {
        // Manually add spaces between the number and units
            let spacedDuration = formattedDuration
            .replacingOccurrences(of: "d", with: " d")
            .replacingOccurrences(of: "h", with: " h")

            tableData[7].value = spacedDuration
            }
        }
        infoTable.reloadData()
    }
}
