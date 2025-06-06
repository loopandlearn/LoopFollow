// LoopFollow
// SMB.swift
// Created by Jonas Björkert on 2023-10-05.

import Foundation

extension MainViewController {
    // NS SMB Processor
    func processNSSmb(entries: [[String: AnyObject]]) {
        smbData.removeAll()
        var lastFoundIndex = 0

        for currentEntry in entries.reversed() {
            var bolusDate: String
            if currentEntry["timestamp"] != nil {
                bolusDate = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                bolusDate = currentEntry["created_at"] as! String
            } else {
                continue
            }

            guard let parsedDate = NightscoutUtils.parseDate(bolusDate),
                  let bolus = currentEntry["insulin"] as? Double else { continue }

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
                smbData.append(dot)
            }
        }

        if Storage.shared.graphBolus.value {
            updateSmbGraph()
            updateChartRenderers()
        }
    }
}
