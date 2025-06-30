// LoopFollow
// ResumePump.swift
// Created by Jonas Björkert.

import Foundation

extension MainViewController {
    // NS Resume Pump Response Processor
    func processResumePump(entries: [[String: AnyObject]]) {
        resumeGraphData.removeAll()

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
                resumeGraphData.append(dot)
            }
        }

        if Storage.shared.graphOtherTreatments.value {
            updateResumeGraph()
        }
    }
}
