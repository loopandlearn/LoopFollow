// LoopFollow
// Overrides.swift
// Created by Jonas Björkert.

import Foundation
import UIKit

extension MainViewController {
    func processNSOverrides(entries: [[String: AnyObject]]) {
        overrideGraphData.removeAll()
        var activeOverrideNote: String?

        let sorted = entries.sorted { lhs, rhs in
            guard
                let ls = (lhs["timestamp"] as? String) ?? (lhs["created_at"] as? String),
                let rs = (rhs["timestamp"] as? String) ?? (rhs["created_at"] as? String),
                let ld = NightscoutUtils.parseDate(ls),
                let rd = NightscoutUtils.parseDate(rs)
            else { return false }
            return ld < rd
        }

        let now = Date().timeIntervalSince1970
        let minimumFutureDisplayHours = 1.0
        let effectiveFutureHours = max(Storage.shared.predictionToLoad.value, minimumFutureDisplayHours)
        let maxEndDate = now + effectiveFutureHours * 3600

        let graphHorizon = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * Storage.shared.downloadDays.value)

        for i in 0 ..< sorted.count {
            let e = sorted[i]

            guard
                let dateStr = (e["timestamp"] as? String) ?? (e["created_at"] as? String),
                let startDate = NightscoutUtils.parseDate(dateStr)
            else { continue }

            let start = max(startDate.timeIntervalSince1970, graphHorizon)

            var end: TimeInterval
            if (e["durationType"] as? String) == "indefinite" { // Only for Loop overrides
                end = maxEndDate
            } else {
                end = start + (e["duration"] as? Double ?? 5) * 60
            }

            if i + 1 < sorted.count,
               let nextDateStr = (sorted[i + 1]["timestamp"] as? String) ?? (sorted[i + 1]["created_at"] as? String),
               let nextStart = NightscoutUtils.parseDate(nextDateStr)?
               .timeIntervalSince1970
            {
                end = min(end, nextStart - 60) // avoid overlapping overrides
            }

            end = min(end, maxEndDate)

            if end - start < 300 { continue } // skip short overrides

            let dot = DataStructs.overrideStruct(
                insulNeedsScaleFactor: e["insulinNeedsScaleFactor"] as? Double ?? 1,
                date: start,
                endDate: end,
                duration: end - start,
                correctionRange: {
                    if let r = e["correctionRange"] as? [Int], r.count == 2 {
                        return r
                    }
                    let lo = e["targetBottom"] as? Int ?? 0
                    let hi = e["targetTop"] as? Int ?? 0
                    return [lo, hi]
                }(),
                enteredBy: e["enteredBy"] as? String ?? "unknown",
                reason: e["reason"] as? String ?? "",
                sgv: -20
            )
            overrideGraphData.append(dot)

            if now >= start, now < end {
                activeOverrideNote = e["notes"] as? String ?? e["reason"] as? String
            }
        }

        Observable.shared.override.value = activeOverrideNote
        if Storage.shared.device.value == "Trio" {
            if let note = activeOverrideNote {
                infoManager.updateInfoData(type: .override, value: note)
            } else {
                infoManager.clearInfoData(type: .override)
            }
        }
        if Storage.shared.graphOtherTreatments.value {
            updateOverrideGraph()
        }
    }
}
