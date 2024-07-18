// DeviceStatusOpenAPS.swift
// LoopFollow
// Created by Jonas Björkert on 2024-05-19.
// Copyright © 2024 Jon Fawcett. All rights reserved.

import Foundation
import UIKit
import HealthKit

extension MainViewController {
    func DeviceStatusOpenAPS(formatter: ISO8601DateFormatter, lastDeviceStatus: [String: AnyObject]?, lastLoopRecord: [String: AnyObject]) {
        if let lastLoopTime = formatter.date(from: (lastDeviceStatus?["created_at"] as! String))?.timeIntervalSince1970 {
            UserDefaultsRepository.alertLastLoopTime.value = lastLoopTime
            if lastLoopRecord["failureReason"] != nil {
                LoopStatusLabel.text = "X"
                latestLoopStatusString = "X"
            } else {
                guard let enacted = lastLoopRecord["enacted"] as? [String: AnyObject] else {
                    LoopStatusLabel.text = "↻"
                    latestLoopStatusString = "↻"
                    evaluateNotLooping(lastLoopTime: lastLoopTime)
                    return
                }
                let wasEnacted = true

                var determinedUnit: HKUnit = .milligramsPerDeciliter

                // Determine the unit based on the threshold value since no unit is provided
                if let enactedTargetValue = enacted["threshold"] as? Double {
                    if enactedTargetValue < 40 {
                        determinedUnit = .millimolesPerLiter
                    }
                }

                /*
                 Updated
                 */
                if let enactedTimestamp = enacted["timestamp"] as? String,
                   let enactedTime = formatter.date(from: enactedTimestamp)?.timeIntervalSince1970 {
                    let formattedTime = Localizer.formatTimestampToLocalString(enactedTime)
                    infoManager.updateInfoData(type: .updated, value: formattedTime)
                }

                /*
                 ISF
                 */
                let profileISF = profileManager.currentISF()
                var enactedISF: HKQuantity?
                if let enactedISFValue = enacted["ISF"] as? Double {
                    enactedISF = HKQuantity(unit: determinedUnit, doubleValue: enactedISFValue)
                }
                if let profileISF = profileISF, let enactedISF = enactedISF, profileISF != enactedISF {
                    infoManager.updateInfoData(type: .isf, firstValue: profileISF, secondValue: enactedISF, separator: .arrow)
                } else if let profileISF = profileISF {
                    infoManager.updateInfoData(type: .isf, value: profileISF)
                }

                /*
                 Carb Ratio (CR)
                 */
                let profileCR = profileManager.currentCarbRatio()
                var enactedCR: Double?
                if let reasonString = enacted["reason"] as? String {
                    let pattern = "CR: (\\d+(?:\\.\\d+)?)"
                    if let regex = try? NSRegularExpression(pattern: pattern) {
                        let nsString = reasonString as NSString
                        if let match = regex.firstMatch(in: reasonString, range: NSRange(location: 0, length: nsString.length)) {
                            let crString = nsString.substring(with: match.range(at: 1))
                            enactedCR = Double(crString)
                        }
                    }
                }

                if let profileCR = profileCR, let enactedCR = enactedCR, profileCR != enactedCR {
                    infoManager.updateInfoData(type: .carbRatio, value: profileCR, enactedValue: enactedCR, separator: .arrow)
                } else if let profileCR = profileCR {
                    infoManager.updateInfoData(type: .carbRatio, value: profileCR)
                }

                /*
                 IOB
                 */
                if let iobMetric = InsulinMetric(from: lastLoopRecord["iob"], key: "iob") {
                    infoManager.updateInfoData(type: .iob, value: iobMetric)
                    latestIOB = iobMetric
                }

                /*
                 COB
                 */
                if let cobMetric = CarbMetric(from: enacted, key: "COB") {
                    infoManager.updateInfoData(type: .cob, value: cobMetric)
                    latestCOB = cobMetric
                }

                /*
                 Insulin Required
                 */
                if let insulinReqMetric = InsulinMetric(from: enacted, key: "insulinReq") {
                    infoManager.updateInfoData(type: .recBolus, value: insulinReqMetric)
                    UserDefaultsRepository.deviceRecBolus.value = insulinReqMetric.value
                } else {
                    UserDefaultsRepository.deviceRecBolus.value = 0
                }

                /*
                 Autosens
                 */
                if let sens = enacted["sensitivityRatio"] as? Double {
                    let formattedSens = String(format: "%.0f", sens * 100.0) + "%"
                    infoManager.updateInfoData(type: .autosens, value: formattedSens)
                }

                /*
                 Eventual BG
                 */
                if let eventualBGValue = enacted["eventualBG"] as? Double {
                    let eventualBGQuantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: eventualBGValue)
                    PredictionLabel.text = Localizer.formatQuantity(eventualBGQuantity)
                }

                /*
                 Target
                 */
                let profileTargetHigh = profileManager.currentTargetHigh()
                var enactedTarget: String?
                if let enactedTargetValue = enacted["current_target"] as? Double {
                    enactedTarget = Localizer.toDisplayUnits(String(enactedTargetValue))
                }
                if let profileTargetHigh = profileTargetHigh, let enactedTarget = enactedTarget, profileTargetHigh != enactedTarget {
                    infoManager.updateInfoData(type: .target, value: "\(profileTargetHigh) → \(enactedTarget)")
                } else if let profileTargetHigh = profileTargetHigh {
                    infoManager.updateInfoData(type: .target, value: profileTargetHigh)
                }

                var predictioncolor = UIColor.systemGray
                PredictionLabel.textColor = predictioncolor
                topPredictionBG = UserDefaultsRepository.minBGScale.value
                if let predbgdata = enacted["predBGs"] as? [String: AnyObject] {
                    let predictionTypes: [(type: String, colorName: String, dataIndex: Int)] = [
                        ("ZT", "ZT", 12),
                        ("IOB", "Insulin", 13),
                        ("COB", "LoopYellow", 14),
                        ("UAM", "UAM", 15)
                    ]

                    var minPredBG = Double.infinity
                    var maxPredBG = -Double.infinity

                    for (type, colorName, dataIndex) in predictionTypes {
                        var predictionData = [ShareGlucoseData]()
                        if let graphdata = predbgdata[type] as? [Double] {
                            var predictionTime = lastLoopTime
                            let toLoad = Int(UserDefaultsRepository.predictionToLoad.value * 12)

                            for i in 0...toLoad {
                                if i < graphdata.count {
                                    let predictionValue = graphdata[i]
                                    minPredBG = min(minPredBG, predictionValue)
                                    maxPredBG = max(maxPredBG, predictionValue)

                                    let prediction = ShareGlucoseData(sgv: Int(round(predictionValue)), date: predictionTime, direction: "flat")
                                    predictionData.append(prediction)
                                    predictionTime += 300
                                }
                            }
                        }

                        let color = UIColor(named: colorName) ?? UIColor.systemPurple
                        updatePredictionGraphGeneric(
                            dataIndex: dataIndex,
                            predictionData: predictionData,
                            chartLabel: type,
                            color: color
                        )
                    }

                    if minPredBG != Double.infinity && maxPredBG != -Double.infinity {
                        let value = "\(Localizer.toDisplayUnits(String(minPredBG)))/\(Localizer.toDisplayUnits(String(maxPredBG)))"
                        infoManager.updateInfoData(type: .minMax, value: value)
                    } else {
                        infoManager.updateInfoData(type: .minMax, value: "N/A")
                    }
                }

                if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String: AnyObject] {
                    if let tempBasalTime = formatter.date(from: (loopStatus["timestamp"] as! String))?.timeIntervalSince1970 {
                        var lastBGTime = lastLoopTime
                        if bgData.count > 0 {
                            lastBGTime = bgData[bgData.count - 1].date
                        }
                        if tempBasalTime > lastBGTime && !wasEnacted {
                            LoopStatusLabel.text = "⏀"
                            latestLoopStatusString = "⏀"
                        } else {
                            LoopStatusLabel.text = "↻"
                            latestLoopStatusString = "↻"
                        }
                    }
                } else {
                    LoopStatusLabel.text = "↻"
                    latestLoopStatusString = "↻"
                }
            }
            evaluateNotLooping(lastLoopTime: lastLoopTime)
        }
    }
}
