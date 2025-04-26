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
        let currentTimeString = dateTimeUtils.getDateTimeString()
        
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
                LogManager.shared.log(category: .nightscout, message: "webLoadNSCage, error: \(error.localizedDescription)")
            }
        }
    }
    
    // NS Cage Response Processor
    func updateCage(data: [cageData]) {
        infoManager.clearInfoData(type: .cage)
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
            
            if let formattedDuration = formatter.string(from: secondsAgo) {
                infoManager.updateInfoData(type: .cage, value: formattedDuration)
            }
        }
    }
}
