//
//  SAGE.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

//TODO: Någon bool för DeepCageSage som bara ska köras en ggn om data inte finns i vanliga Treatments

import Foundation
extension MainViewController {
    // NS Sage Web Call
    func webLoadNSSage() {
        let lastDateString = dateTimeUtils.nowMinus10DaysTimeInterval()
        
        let parameters: [String: String] = [
            "find[eventType]": NightscoutUtils.EventType.sage.rawValue,
            "find[created_at][$gte]": lastDateString,
            "count": "1"
        ]
        
        NightscoutUtils.executeRequest(eventType: .sage, parameters: parameters) { (result: Result<[sageData], Error>) in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self.updateSage(data: data)
                }
            case .failure(let error):
                print("Failed to fetch data: \(error.localizedDescription)")
            }
        }
    }
    
    // NS Sage Response Processor
    func updateSage(data: [sageData]) {
        self.clearLastInfoData(index: 6)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process/Display: SAGE") }
        if data.count == 0 {
            return
        }
        
        var lastSageString = data[0].created_at
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertSageInsertTime.value = formatter.date(from: (lastSageString))?.timeIntervalSince1970 as! TimeInterval
        
        if UserDefaultsRepository.alertAutoSnoozeCGMStart.value && (dateTimeUtils.getNowTimeIntervalUTC() - UserDefaultsRepository.alertSageInsertTime.value < 7200){
            let snoozeTime = Date(timeIntervalSince1970: UserDefaultsRepository.alertSageInsertTime.value + 7200)
            UserDefaultsRepository.alertSnoozeAllTime.value = snoozeTime
            UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = true
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertSnoozeAllIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertSnoozeAllTime", setNil: false, value: snoozeTime)
        }
        
        if let sageTime = formatter.date(from: (lastSageString as! String))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - sageTime
            let days = 24 * 60 * 60
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
            
            let formattedDuration = formatter.string(from: secondsAgo)
            tableData[6].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
}
