// LoopFollow
// DeviceStatusOpenAPS.swift

import Foundation
import HealthKit
import UIKit

extension MainViewController {
    func DeviceStatusOpenAPS(formatter: ISO8601DateFormatter, lastDeviceStatus: [String: AnyObject]?, lastLoopRecord: [String: AnyObject]) {
        Storage.shared.device.value = lastDeviceStatus?["device"] as? String ?? ""
        if lastLoopRecord["failureReason"] != nil {
            LoopStatusLabel.text = "X"
            latestLoopStatusString = "X"
        } else {
            guard let enactedOrSuggested = lastLoopRecord["suggested"] as? [String: AnyObject] ?? lastLoopRecord["enacted"] as? [String: AnyObject] else {
                LoopStatusLabel.text = "↻"
                latestLoopStatusString = "↻"
                return
            }

            var updatedTime: TimeInterval?

            if let timestamp = enactedOrSuggested["timestamp"] as? String,
               let parsedTime = formatter.date(from: timestamp)?.timeIntervalSince1970
            {
                updatedTime = parsedTime
                let formattedTime = Localizer.formatTimestampToLocalString(parsedTime)
                infoManager.updateInfoData(type: .updated, value: formattedTime)
                Observable.shared.enactedOrSuggested.value = updatedTime
            }

            // ISF
            let profileISF = profileManager.currentISF()
            var enactedISF: HKQuantity?
            if let enactedISFValue = enactedOrSuggested["ISF"] as? Double {
                enactedISF = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: enactedISFValue)
            }
            if let profileISF = profileISF, let enactedISF = enactedISF, profileISF != enactedISF {
                infoManager.updateInfoData(type: .isf, firstValue: profileISF, secondValue: enactedISF, separator: .arrow)
            } else if let profileISF = profileISF {
                infoManager.updateInfoData(type: .isf, value: profileISF)
            }

            // Carb Ratio (CR)
            let profileCR = profileManager.currentCarbRatio()
            var enactedCR: Double?
            if let reasonString = enactedOrSuggested["reason"] as? String {
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

            // IOB
            if let iobMetric = InsulinMetric(from: lastLoopRecord["iob"], key: "iob") {
                infoManager.updateInfoData(type: .iob, value: iobMetric)
                latestIOB = iobMetric
                Observable.shared.iobText.value = iobMetric.formattedValue()
            }

            // COB
            if let cobMetric = CarbMetric(from: enactedOrSuggested, key: "COB") {
                infoManager.updateInfoData(type: .cob, value: cobMetric)
                latestCOB = cobMetric
            } else if let reasonString = enactedOrSuggested["reason"] as? String {
                // Fallback: Extract COB from reason string
                let cobPattern = "COB: (\\d+(?:\\.\\d+)?)"
                if let cobRegex = try? NSRegularExpression(pattern: cobPattern),
                   let cobMatch = cobRegex.firstMatch(in: reasonString, range: NSRange(location: 0, length: reasonString.utf16.count))
                {
                    let cobValueString = (reasonString as NSString).substring(with: cobMatch.range(at: 1))
                    if let cobValue = Double(cobValueString) {
                        let tempDict: [String: AnyObject] = ["COB": cobValue as AnyObject]
                        if let fallbackCobMetric = CarbMetric(from: tempDict, key: "COB") {
                            infoManager.updateInfoData(type: .cob, value: fallbackCobMetric)
                            latestCOB = fallbackCobMetric
                        } else {
                            print("Failed to create CarbMetric from extracted COB value: \(cobValue)")
                        }
                    } else {
                        print("Invalid COB value extracted from reason string: \(cobValueString)")
                    }
                } else {
                    print("COB pattern not found in reason string.")
                }
            }

            // Autosens
            if let sens = enactedOrSuggested["sensitivityRatio"] as? Double {
                let formattedSens = String(format: "%.0f", sens * 100.0) + "%"
                infoManager.updateInfoData(type: .autosens, value: formattedSens)
            }

            // Recommended Bolus
            if let rec = InsulinMetric(from: lastLoopRecord, key: "recommendedBolus") {
                infoManager.updateInfoData(type: .recBolus, value: rec)
                Observable.shared.deviceRecBolus.value = rec.value
            } else {
                Observable.shared.deviceRecBolus.value = nil
            }

            // Eventual BG
            if let eventualBGValue = enactedOrSuggested["eventualBG"] as? Double {
                let eventualBGQuantity = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: eventualBGValue)
                PredictionLabel.text = Localizer.formatQuantity(eventualBGQuantity)
            }

            // Target
            let profileTargetHigh = profileManager.currentTargetHigh()
            var enactedTarget: HKQuantity?
            if let enactedTargetValue = enactedOrSuggested["current_target"] as? Double {
                var targetUnit = HKUnit.milligramsPerDeciliter
                if enactedTargetValue < 40 {
                    targetUnit = .millimolesPerLiter
                }
                enactedTarget = HKQuantity(unit: targetUnit, doubleValue: enactedTargetValue)
            }

            if let profileTargetHigh = profileTargetHigh, let enactedTarget = enactedTarget {
                let profileTargetHighFormatted = Localizer.formatQuantity(profileTargetHigh)
                let enactedTargetFormatted = Localizer.formatQuantity(enactedTarget)

                // Compare formatted values to avoid issues with minor floating-point differences
                // Profile target could be in another unit than enacted target
                if profileTargetHighFormatted != enactedTargetFormatted {
                    infoManager.updateInfoData(type: .target, firstValue: profileTargetHigh, secondValue: enactedTarget, separator: .arrow)
                } else {
                    infoManager.updateInfoData(type: .target, value: profileTargetHigh)
                }
            }

            // TDD
            if let tddMetric = InsulinMetric(from: enactedOrSuggested, key: "TDD") {
                infoManager.updateInfoData(type: .tdd, value: tddMetric)
            }

            let predBGsData: [String: AnyObject]? = {
                if let enacted = lastLoopRecord["suggested"] as? [String: AnyObject],
                   let predBGs = enacted["predBGs"] as? [String: AnyObject]
                {
                    return predBGs
                } else if let suggested = lastLoopRecord["enacted"] as? [String: AnyObject],
                          let predBGs = suggested["predBGs"] as? [String: AnyObject]
                {
                    return predBGs
                }
                return nil
            }()

            let predictioncolor = UIColor.systemGray
            PredictionLabel.textColor = predictioncolor
            topPredictionBG = Storage.shared.minBGScale.value
            if let predbgdata = predBGsData {
                let predictionTypes: [(type: String, colorName: String, dataIndex: Int)] = [
                    ("ZT", "ZT", 12),
                    ("IOB", "Insulin", 13),
                    ("COB", "LoopYellow", 14),
                    ("UAM", "UAM", 15),
                ]

                var minPredBG = Double.infinity
                var maxPredBG = -Double.infinity

                for (type, colorName, dataIndex) in predictionTypes {
                    var predictionData = [ShareGlucoseData]()
                    if let graphdata = predbgdata[type] as? [Double] {
                        var predictionTime = updatedTime ?? Date().timeIntervalSince1970
                        let toLoad = Int(Storage.shared.predictionToLoad.value * 12)

                        for i in 0 ... toLoad {
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

                if minPredBG != Double.infinity, maxPredBG != -Double.infinity {
                    let value = "\(Localizer.toDisplayUnits(String(minPredBG)))/\(Localizer.toDisplayUnits(String(maxPredBG)))"
                    infoManager.updateInfoData(type: .minMax, value: value)
                } else {
                    infoManager.updateInfoData(type: .minMax, value: "N/A")
                }
            }

            if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String: AnyObject] {
                if let tempBasalTime = formatter.date(from: (loopStatus["timestamp"] as! String))?.timeIntervalSince1970 {
                    var lastBGTime = updatedTime ?? Date().timeIntervalSince1970
                    if bgData.count > 0 {
                        lastBGTime = bgData[bgData.count - 1].date
                    }
                    if tempBasalTime > lastBGTime {
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
    }
}
