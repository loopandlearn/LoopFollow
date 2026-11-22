// LoopFollow
// Basals.swift

import Foundation

extension MainViewController {
    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String: AnyObject]], suspensions: [DateInterval] = []) {
        infoManager.clearInfoData(type: .basal)

        basalData.removeAll()

        var lastEndDot = 0.0

        var tempArray = entries
        tempArray.reverse()

        for i in 0 ..< tempArray.count {
            guard let currentEntry = tempArray[i] as [String: AnyObject]? else { continue }

            // Decide which field to parse
            let dateString = currentEntry["timestamp"] as? String
                ?? currentEntry["created_at"] as? String
            guard let rawDateStr = dateString,
                  let dateParsed = NightscoutUtils.parseDate(rawDateStr)
            else {
                continue
            }

            let dateTimeStamp = dateParsed.timeIntervalSince1970
            guard let basalRate = currentEntry["absolute"] as? Double else {
                continue
            }

            let duration = currentEntry["duration"] as? Double ?? 0.0

            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String: AnyObject]?
                let priorDateStr = priorEntry?["timestamp"] as? String
                    ?? priorEntry?["created_at"] as? String
                if let rawPrior = priorDateStr,
                   let priorDateParsed = NightscoutUtils.parseDate(rawPrior)
                {
                    let priorDateTimeStamp = priorDateParsed.timeIntervalSince1970
                    let priorDuration = priorEntry?["duration"] as? Double ?? 0.0

                    let priorEnd = priorDateTimeStamp + (priorDuration * 60)
                    if dateTimeStamp - priorEnd > 15 {
                        appendScheduledBasal(from: priorEnd, to: dateTimeStamp)
                    }
                }
            }

            // Start dot
            let startDot = basalGraphStruct(basalRate: basalRate, date: dateTimeStamp)
            basalData.append(startDot)

            // End dot
            var lastDot = dateTimeStamp + (duration * 60)
            if i == tempArray.count - 1, duration == 0.0 {
                lastDot = dateTimeStamp + (30 * 60)
            }
            latestBasal = Localizer.formatToLocalizedString(basalRate, maxFractionDigits: 2, minFractionDigits: 0)

            // Overlap check
            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String: AnyObject]?
                let nextDateStr = nextEntry?["timestamp"] as? String
                    ?? nextEntry?["created_at"] as? String
                if let rawNext = nextDateStr,
                   let nextDateParsed = NightscoutUtils.parseDate(rawNext)
                {
                    let nextDateTimeStamp = nextDateParsed.timeIntervalSince1970
                    if nextDateTimeStamp < (dateTimeStamp + (duration * 60)) {
                        lastDot = nextDateTimeStamp
                    }
                }
            }

            let endDot = basalGraphStruct(basalRate: basalRate, date: lastDot)
            basalData.append(endDot)
            lastEndDot = lastDot
        }

        // If last basal was prior to right now, fill up to now with the scheduled basal
        if lastEndDot <= dateTimeUtils.getNowTimeIntervalUTC() {
            let now = Date()
            latestBasal = Localizer.formatToLocalizedString(profileManager.basalRate(at: now) ?? 0.0,
                                                            maxFractionDigits: 2,
                                                            minFractionDigits: 0)
            appendScheduledBasal(from: max(lastEndDot, dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * Storage.shared.downloadDays.value)),
                                 to: now.timeIntervalSince1970 + 60 * 10)
        }

        basalData = PumpSuspension.applying(suspensions, to: basalData)
        if suspensions.contains(where: { $0.contains(Date()) }) {
            latestBasal = Localizer.formatToLocalizedString(0.0, maxFractionDigits: 2, minFractionDigits: 0)
        }

        if Storage.shared.graphBasal.value {
            updateBasalGraph()
        }

        if let profileBasal = profileManager.currentBasal(),
           profileBasal != latestBasal
        {
            latestBasal = "\(profileBasal) → \(latestBasal)"
        }
        infoManager.updateInfoData(type: .basal, value: latestBasal)
        Storage.shared.lastBasal.value = latestBasal
    }

    /// Appends the scheduled basal from `start` to `end` as rate steps, split
    /// at each schedule entry in between.
    private func appendScheduledBasal(from start: TimeInterval, to end: TimeInterval) {
        guard end > start else { return }
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        var segments = profileManager.scheduledBasalSegments(from: startDate, to: endDate)
        if segments.isEmpty {
            segments = [(start: startDate, rate: 0.0)]
        }
        for (index, segment) in segments.enumerated() {
            let segmentEnd = index < segments.count - 1 ? segments[index + 1].start : endDate
            basalData.append(basalGraphStruct(basalRate: segment.rate, date: segment.start.timeIntervalSince1970))
            basalData.append(basalGraphStruct(basalRate: segment.rate, date: segmentEnd.timeIntervalSince1970))
        }
    }
}
