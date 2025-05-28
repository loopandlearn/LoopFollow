// LoopFollow
// SAge.swift
// Created by Jonas Björkert on 2023-10-05.

import Foundation

extension MainViewController {
    // NS Sage Web Call
    func webLoadNSSage() {
        let lastDateString = dateTimeUtils.getDateTimeString(addingDays: -60)
        let currentTimeString = dateTimeUtils.getDateTimeString()

        let parameters: [String: String] = [
            "find[eventType]": NightscoutUtils.EventType.sage.rawValue,
            "find[created_at][$gte]": lastDateString,
            "find[created_at][$lte]": currentTimeString,
            "count": "1",
        ]

        NightscoutUtils.executeRequest(eventType: .sage, parameters: parameters) { (result: Result<[sageData], Error>) in
            switch result {
            case let .success(data):
                DispatchQueue.main.async {
                    self.updateSage(data: data)
                }
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "webLoadNSSage, failed to fetch data: \(error.localizedDescription)")
            }
        }
    }

    // NS Sage Response Processor
    func updateSage(data: [sageData]) {
        infoManager.clearInfoData(type: .sage)

        if data.count == 0 {
            return
        }
        currentSage = data[0]
        var lastSageString = data[0].created_at

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertSageInsertTime.value = formatter.date(from: lastSageString)?.timeIntervalSince1970 as! TimeInterval

        // -- Auto-snooze CGM start ────────────────────────────────────────────────
        let now = Date()

        // 1.  Do we *want* the automatic global snooze?
        if Storage.shared.alarmConfiguration.value.autoSnoozeCGMStart {
            // 2.  When did the sensor start?
            let insertTime = UserDefaultsRepository.alertSageInsertTime.value

            // 3.  If the start is less than 2 h ago, snooze *all* alarms for the
            //     remainder of that 2-hour window.
            if now.timeIntervalSince1970 - insertTime < 7200 {
                var cfg = Storage.shared.alarmConfiguration.value
                cfg.snoozeUntil = Date(timeIntervalSince1970: insertTime + 7200)
                Storage.shared.alarmConfiguration.value = cfg
            }
        }

        if let sageTime = formatter.date(from: (lastSageString as! String))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - sageTime

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [.day, .hour] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [.pad] // Pad with zeroes where appropriate for the locale

            if let formattedDuration = formatter.string(from: secondsAgo) {
                infoManager.updateInfoData(type: .sage, value: formattedDuration)
            }
        }
    }
}
