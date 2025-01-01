//
//  Basals.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {

    private func parseDate(_ rawString: String) -> Date? {
        var mutableDate = rawString

        if mutableDate.hasSuffix("Z") {
            mutableDate = String(mutableDate.dropLast())
        }
        else if let offsetRange = mutableDate.range(of: "[\\+\\-]\\d{2}:\\d{2}$",
                                                    options: .regularExpression) {
            mutableDate.removeSubrange(offsetRange)
        }

        mutableDate = mutableDate.replacingOccurrences(
            of: "\\.\\d+",
            with: "",
            options: .regularExpression
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        return dateFormatter.date(from: mutableDate)
    }

    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String:AnyObject]]) {
        infoManager.clearInfoData(type: .basal)

        basalData.removeAll()

        var lastEndDot = 0.0

        var tempArray = entries
        tempArray.reverse()

        for i in 0..<tempArray.count {
            guard let currentEntry = tempArray[i] as [String : AnyObject]? else { continue }

            // Decide which field to parse
            let dateString = currentEntry["timestamp"] as? String
            ?? currentEntry["created_at"] as? String
            guard let rawDateStr = dateString,
                  let dateParsed = parseDate(rawDateStr) else {
                continue
            }

            let dateTimeStamp = dateParsed.timeIntervalSince1970
            guard let basalRate = currentEntry["absolute"] as? Double else {
                self.writeDebugLog(value: "ERROR: Null Basal entry")
                continue
            }

            let duration = currentEntry["duration"] as? Double ?? 0.0

            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String : AnyObject]?
                let priorDateStr = priorEntry?["timestamp"] as? String
                ?? priorEntry?["created_at"] as? String
                if let rawPrior = priorDateStr,
                   let priorDateParsed = parseDate(rawPrior) {

                    let priorDateTimeStamp = priorDateParsed.timeIntervalSince1970
                    let priorDuration = priorEntry?["duration"] as? Double ?? 0.0

                    if (dateTimeStamp - priorDateTimeStamp) > (priorDuration * 60) + 15 {
                        var scheduled = 0.0
                        var midGap = false
                        var midGapTime: TimeInterval = 0
                        var midGapValue: Double = 0

                        for b in 0..<basalScheduleData.count {
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
                let nextEntry = tempArray[i + 1] as [String : AnyObject]?
                let nextDateStr = nextEntry?["timestamp"] as? String
                ?? nextEntry?["created_at"] as? String
                if let rawNext = nextDateStr,
                   let nextDateParsed = parseDate(rawNext) {

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

        // If last basal was prior to right now, we need to create one last scheduled entry
        if lastEndDot <= dateTimeUtils.getNowTimeIntervalUTC() {
            var scheduled = 0.0
            for b in 0..<basalProfile.count {
                let scheduleTimeToday = basalProfile[b].timeAsSeconds
                + dateTimeUtils.getTimeIntervalMidnightToday()
                if lastEndDot >= scheduleTimeToday {
                    scheduled = basalProfile[b].value
                }
            }

            latestBasal = Localizer.formatToLocalizedString(scheduled,
                                                            maxFractionDigits: 2,
                                                            minFractionDigits: 0)

            let startDot = basalGraphStruct(basalRate: scheduled, date: lastEndDot)
            basalData.append(startDot)

            let endDot = basalGraphStruct(basalRate: scheduled,
                                          date: Date().timeIntervalSince1970 + (60 * 10))
            basalData.append(endDot)
        }

        if UserDefaultsRepository.graphBasal.value {
            updateBasalGraph()
        }

        if let profileBasal = profileManager.currentBasal(),
           profileBasal != latestBasal {
            latestBasal = "\(profileBasal) → \(latestBasal)"
        }
        infoManager.updateInfoData(type: .basal, value: latestBasal)
    }
}
