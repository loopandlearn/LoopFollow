//
//  IAge.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-05.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {
    // NS Iage Web Call
    func webLoadNSIage() {
        let lastDateString = dateTimeUtils.getDateTimeString(addingDays: -60)
        let currentTimeString = dateTimeUtils.getDateTimeString()

        let parameters: [String: String] = [
            "find[eventType]": NightscoutUtils.EventType.iage.rawValue,
            "find[created_at][$gte]": lastDateString,
            "find[created_at][$lte]": currentTimeString,
            "count": "1",
        ]

        NightscoutUtils.executeRequest(eventType: .iage, parameters: parameters) { (result: Result<[iageData], Error>) in
            switch result {
            case let .success(data):
                DispatchQueue.main.async {
                    self.updateIage(data: data)
                }
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "webLoadNSIage, failed to fetch data: \(error.localizedDescription)")
            }
        }
    }

    // NS Sage Response Processor
    func updateIage(data: [iageData]) {
        infoManager.clearInfoData(type: .iage)

        if data.count == 0 {
            return
        }
        currentIage = data[0]
        let lastIageString = data[0].created_at

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]

        if let iageTime = formatter.date(from: (lastIageString as! String))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - iageTime

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional
            formatter.allowedUnits = [.day, .hour]
            formatter.zeroFormattingBehavior = [.pad]

            if let formattedDuration = formatter.string(from: secondsAgo) {
                infoManager.updateInfoData(type: .iage, value: formattedDuration)
            }
        }
    }
}
