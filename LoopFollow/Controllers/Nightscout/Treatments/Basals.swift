// LoopFollow
// Basals.swift

import Foundation

extension MainViewController {
    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String: AnyObject]]) {
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

                    if (dateTimeStamp - priorDateTimeStamp) > (priorDuration * 60) + 15 {
                        var scheduled = 0.0
                        var midGap = false
                        var midGapTime: TimeInterval = 0
                        var midGapValue: Double = 0

                        for b in 0 ..< basalScheduleData.count {
                            let priorEnd = priorDateTimeStamp + (priorDuration * 60)
                            if priorEnd >= basalScheduleData[b].date {
                                scheduled = basalScheduleData[b].basalRate
                                if b < basalScheduleData.count - 1 {
                                    if dateTimeStamp > basalScheduleData[b + 1].date {
                                        midGap = true
                                        midGapTime = basalScheduleData[b + 1].date
                                        midGapValue = basalScheduleData[b + 1].basalRate
                                    }
                                }
                            }
                        }

                        let startDot = basalGraphStruct(basalRate: scheduled,
                                                        date: priorDateTimeStamp + (priorDuration * 60))
                        basalData.append(startDot)

                        if midGap {
                            let endDot1 = basalGraphStruct(basalRate: scheduled, date: midGapTime)
                            basalData.append(endDot1)
                            let startDot2 = basalGraphStruct(basalRate: midGapValue, date: midGapTime)
                            basalData.append(startDot2)
                            let endDot2 = basalGraphStruct(basalRate: midGapValue, date: dateTimeStamp)
                            basalData.append(endDot2)
                        } else {
                            let endDot = basalGraphStruct(basalRate: scheduled, date: dateTimeStamp)
                            basalData.append(endDot)
                        }
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
            let tailStart = Date(timeIntervalSince1970: max(lastEndDot, dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * Storage.shared.downloadDays.value)))
            let tailEnd = now.addingTimeInterval(60 * 10)

            latestBasal = Localizer.formatToLocalizedString(profileManager.basalRate(at: now) ?? 0.0,
                                                            maxFractionDigits: 2,
                                                            minFractionDigits: 0)

            var segments = profileManager.scheduledBasalSegments(from: tailStart, to: tailEnd)
            if segments.isEmpty {
                segments = [(start: tailStart, rate: 0.0)]
            }

            for (index, segment) in segments.enumerated() {
                let segmentEnd = index < segments.count - 1 ? segments[index + 1].start : tailEnd
                basalData.append(basalGraphStruct(basalRate: segment.rate, date: segment.start.timeIntervalSince1970))
                basalData.append(basalGraphStruct(basalRate: segment.rate, date: segmentEnd.timeIntervalSince1970))
            }
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
}
