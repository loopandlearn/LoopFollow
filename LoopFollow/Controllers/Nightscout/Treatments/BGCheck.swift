// LoopFollow
// BGCheck.swift
// Created by Jonas Björkert on 2023-10-05.

import Foundation
import UIKit

extension MainViewController {
    // NS BG Check Response Processor
    func processNSBGCheck(entries: [[String: AnyObject]]) {
        bgCheckData.removeAll()

        for currentEntry in entries.reversed() {
            guard let dateStr = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String else { continue }

            guard let parsedDate = NightscoutUtils.parseDate(dateStr),
                  let glucose = currentEntry["glucose"] as? Double
            else {
                continue
            }

            let units = currentEntry["units"] as? String ?? "mg/dl"
            let convertedGlucose: Double = units == "mmol" ? glucose * GlucoseConversion.mmolToMgDl : glucose

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                let dot = ShareGlucoseData(sgv: Int(convertedGlucose.rounded()), date: Double(dateTimeStamp), direction: "")
                bgCheckData.append(dot)
            }
        }

        if Storage.shared.graphOtherTreatments.value {
            updateBGCheckGraph()
        }
    }
}
