// LoopFollow
// SuspendPump.swift
// Created by Jonas Björkert on 2023-10-05.

import Foundation

extension MainViewController {
    // NS Suspend Pump Response Processor
    func processSuspendPump(entries: [[String: AnyObject]]) {
        suspendGraphData.removeAll()

        var lastFoundIndex = 0

        for currentEntry in entries.reversed() {
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { continue }

            guard let parsedDate = NightscoutUtils.parseDate(dateStr) else {
                continue
            }

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                suspendGraphData.append(dot)
            }
        }

        if Storage.shared.graphOtherTreatments.value {
            updateSuspendGraph()
        }
    }
}
