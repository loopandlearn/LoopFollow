// LoopFollow
// Overrides.swift

import Foundation

extension MainViewController {
    func processNSOverrides(entries: [[String: AnyObject]]) {
        overrideGraphData.removeAll()
        var activeOverrideNote: String?
        var activeOverrideEndAt: TimeInterval?
        var activeOverridePercent: Int?
        var activeOverrideRange: (low: Double, high: Double)?

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
        let minimumFutureDisplayHours = 0.25
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

            let nextStart: TimeInterval? = {
                guard i + 1 < sorted.count,
                      let nextDateStr = (sorted[i + 1]["timestamp"] as? String) ?? (sorted[i + 1]["created_at"] as? String)
                else { return nil }
                return NightscoutUtils.parseDate(nextDateStr)?.timeIntervalSince1970
            }()

            let durationSeconds = (e["duration"] as? Double ?? 5) * 60
            // Loop marks indefinite overrides explicitly; Trio represents them
            // as a ~30-day duration. Treat a week or longer as indefinite.
            let isIndefinite = (e["durationType"] as? String) == "indefinite"
                || durationSeconds >= 7 * 24 * 3600

            var end: TimeInterval = isIndefinite ? maxEndDate : start + durationSeconds

            // True end for countdown display and the end alarm's early
            // warning: based on the raw start and never clamped to the graph
            // edge; nil while indefinite.
            var trueEnd: TimeInterval? = isIndefinite ? nil : startDate.timeIntervalSince1970 + durationSeconds

            if let nextStart = nextStart {
                end = min(end, nextStart - 60) // avoid overlapping overrides
                trueEnd = trueEnd.map { min($0, nextStart - 60) }
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
                // Loop stores the override name in "reason"; Trio stores it in
                // "notes". Prefer notes so Trio override names surface on the
                // graph, matching the info table and treatments list.
                reason: (e["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (e["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "",
                sgv: -20,
                scheduledEndDate: trueEnd,
                detail: Treatment.historyEntries(from: e, date: startDate.timeIntervalSince1970) { 0 }.entries.first
            )
            overrideGraphData.append(dot)

            if now >= start, now < end {
                activeOverrideNote = e["notes"] as? String ?? e["reason"] as? String
                activeOverrideEndAt = trueEnd
                activeOverridePercent = WatchStateBuilder.overridePercent(dot)
                activeOverrideRange = Self.overrideRangeMgdl(dot.correctionRange)
            }
        }

        Observable.shared.override.value = activeOverrideNote
        Observable.shared.overrideEndAt.value = activeOverrideEndAt
        Observable.shared.overridePercent.value = activeOverridePercent
        Observable.shared.overrideRangeLowMgdl.value = activeOverrideRange?.low
        Observable.shared.overrideRangeHighMgdl.value = activeOverrideRange?.high
        if Storage.shared.device.value != "Loop" {
            if let note = activeOverrideNote {
                infoManager.updateInfoData(type: .override, value: note)
            } else {
                infoManager.clearInfoData(type: .override)
            }
        }
        if Storage.shared.graphOtherTreatments.value {
            updateOverrideGraph()
        }

        #if !targetEnvironment(macCatalyst)
            LiveActivityManager.shared.refreshFromCurrentState(reason: "overrideChanged")
        #endif
    }

    /// An override's target range in mg/dL, or nil when it sets none (stored as
    /// [0, 0]). Values this small can only be mmol/L, so they are converted.
    nonisolated static func overrideRangeMgdl(_ range: [Int]) -> (low: Double, high: Double)? {
        guard range.count == 2, range[0] > 0, range[1] > 0 else { return nil }
        let mgdl = range.map { $0 < 30 ? Double($0) * GlucoseConversion.mmolToMgDl : Double($0) }
        return (min(mgdl[0], mgdl[1]), max(mgdl[0], mgdl[1]))
    }
}
