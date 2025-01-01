//
//  Basals.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {
    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String:AnyObject]]) {
        infoManager.clearInfoData(type: .basal)

        basalData.removeAll()

        var lastEndDot = 0.0

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var tempArray = entries
        tempArray.reverse()

        for i in 0..<tempArray.count {
            let currentEntry = tempArray[i] as [String : AnyObject]?

            var basalDateStr: String
            if let ts = currentEntry?["timestamp"] as? String {
                basalDateStr = ts
            } else if let ca = currentEntry?["created_at"] as? String {
                basalDateStr = ca
            } else {
                continue
            }

            guard let dateParsed = isoFormatter.date(from: basalDateStr) else {
                continue
            }
            let dateTimeStamp = dateParsed.timeIntervalSince1970

            guard let basalRate = currentEntry?["absolute"] as? Double else {
                if UserDefaultsRepository.debugLog.value {
                    self.writeDebugLog(value: "ERROR: Null Basal entry")
                }
                continue
            }

            var duration = 0.0
            if let durationValue = currentEntry?["duration"] as? Double {
                duration = durationValue
            } else {
                print("No Duration Found")
            }

            // *** Check for any gap since the previous entry
            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String : AnyObject]?

                var priorBasalDateStr: String
                if let ts = priorEntry?["timestamp"] as? String {
                    priorBasalDateStr = ts
                } else if let ca = priorEntry?["created_at"] as? String {
                    priorBasalDateStr = ca
                } else {
                    continue
                }

                guard let priorDateParsed = isoFormatter.date(from: priorBasalDateStr) else {
                    continue
                }
                let priorDateTimeStamp = priorDateParsed.timeIntervalSince1970
                let priorDuration = priorEntry?["duration"] as? Double ?? 0.0

                // if difference between time stamps is greater than the duration of the last entry, there is a gap. Give a 15 second leeway on the timestamp
                if Double(dateTimeStamp - priorDateTimeStamp) > Double((priorDuration * 60) + 15) {

                    var scheduled = 0.0
                    let midGap = false
                    var midGapTime: TimeInterval = 0
                    var midGapValue: Double = 0

                    for b in 0..<self.basalScheduleData.count {
                        let priorEnd = priorDateTimeStamp + (priorDuration * 60)
                        if priorEnd >= basalScheduleData[b].date {
                            scheduled = basalScheduleData[b].basalRate

                            if b < self.basalScheduleData.count - 1 {
                                if dateTimeStamp > self.basalScheduleData[b + 1].date {
                                    // midGap = true
                                    // TODO: finish this to handle mid-gap items without crashing from overlapping entries
                                    midGapTime = self.basalScheduleData[b + 1].date
                                    midGapValue = self.basalScheduleData[b + 1].basalRate
                                }
                            }
                        }
                    }

                    // Make the starting dot at the last ending dot
                    let startDot = basalGraphStruct(
                        basalRate: scheduled,
                        date: priorDateTimeStamp + (priorDuration * 60)
                    )
                    basalData.append(startDot)

                    if midGap {
                        // Make the ending dot at the old scheduled basal
                        let endDot1 = basalGraphStruct(basalRate: scheduled, date: midGapTime)
                        basalData.append(endDot1)
                        // Make the starting dot at the scheduled Time
                        let startDot2 = basalGraphStruct(basalRate: midGapValue, date: midGapTime)
                        basalData.append(startDot2)
                        // Make the ending dot at the new basal value
                        let endDot2 = basalGraphStruct(basalRate: midGapValue, date: dateTimeStamp)
                        basalData.append(endDot2)
                    } else {
                        // Make the ending dot at the new starting dot
                        let endDot = basalGraphStruct(basalRate: scheduled, date: dateTimeStamp)
                        basalData.append(endDot)
                    }
                }
            }

            // Make the starting dot
            let startDot = basalGraphStruct(basalRate: basalRate, date: dateTimeStamp)
            basalData.append(startDot)

            // Make the ending dot
            if i == tempArray.count - 1 && duration == 0.0 {
                // If it's the last one and has no duration
                lastEndDot = dateTimeStamp + (30 * 60)
            } else {
                lastEndDot = dateTimeStamp + (duration * 60)
            }
            latestBasal = Localizer.formatToLocalizedString(basalRate,
                                                            maxFractionDigits: 2,
                                                            minFractionDigits: 0)

            // *** Overlap check for next entry
            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String : AnyObject]?
                var nextBasalDateStr: String
                if let ts = nextEntry?["timestamp"] as? String {
                    nextBasalDateStr = ts
                } else if let ca = nextEntry?["created_at"] as? String {
                    nextBasalDateStr = ca
                } else {
                    continue
                }

                guard let nextDateParsed = isoFormatter.date(from: nextBasalDateStr) else {
                    continue
                }
                let nextDateTimeStamp = nextDateParsed.timeIntervalSince1970
                if nextDateTimeStamp < (dateTimeStamp + (duration * 60)) {
                    lastEndDot = nextDateTimeStamp
                }
            }

            let endDot = basalGraphStruct(basalRate: basalRate, date: lastEndDot)
            basalData.append(endDot)
        }

        // If last basal was prior to right now, we need to create one last scheduled entry
        if lastEndDot <= dateTimeUtils.getNowTimeIntervalUTC() {
            var scheduled = 0.0
            for b in 0..<self.basalProfile.count {
                let scheduleTimeToday = self.basalProfile[b].timeAsSeconds
                + dateTimeUtils.getTimeIntervalMidnightToday()
                if lastEndDot >= scheduleTimeToday {
                    scheduled = basalProfile[b].value
                }
            }

            latestBasal = Localizer.formatToLocalizedString(
                scheduled,
                maxFractionDigits: 2,
                minFractionDigits: 0
            )

            // Make the starting dot at the last ending dot
            let startDot = basalGraphStruct(
                basalRate: scheduled,
                date: lastEndDot
            )
            basalData.append(startDot)

            // Make the ending dot 10 minutes after now
            let endDot = basalGraphStruct(
                basalRate: scheduled,
                date: Date().timeIntervalSince1970 + (60 * 10)
            )
            basalData.append(endDot)
        }

        if UserDefaultsRepository.graphBasal.value {
            updateBasalGraph()
        }

        if let profileBasal = profileManager.currentBasal(), profileBasal != latestBasal {
            latestBasal = "\(profileBasal) → \(latestBasal)"
        }
        infoManager.updateInfoData(type: .basal, value: latestBasal)
    }
}
