//
//  DeviceStatusLoop.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-06-16.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import Charts

extension MainViewController {
    func DeviceStatusLoop(formatter: ISO8601DateFormatter, lastLoopRecord: [String: AnyObject]) {
        
        if let lastLoopTime = formatter.date(from: (lastLoopRecord["timestamp"] as! String))?.timeIntervalSince1970  {
            UserDefaultsRepository.alertLastLoopTime.value = lastLoopTime
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "lastLoopTime: " + String(lastLoopTime)) }
            if let failure = lastLoopRecord["failureReason"] {
                LoopStatusLabel.text = "X"
                latestLoopStatusString = "X"
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Loop Failure: X") }
            } else {
                var wasEnacted = false
                if let enacted = lastLoopRecord["enacted"] as? [String:AnyObject] {
                    if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Loop: Was Enacted") }
                    wasEnacted = true
                    if let lastTempBasal = enacted["rate"] as? Double {
                        
                    }
                }

                /*
                 ISF
                 */
                let profileISF = profileManager.currentISF()
                if let profileISF = profileISF {
                    infoManager.updateInfoData(type: .isf, value: profileISF)
                }

                /*
                 Carb Ratio (CR)
                 */
                let profileCR = profileManager.currentCarbRatio()
                if let profileCR = profileCR {
                    infoManager.updateInfoData(type: .carbRatio, value: profileCR)
                }

                /*
                 Target
                 */
                let profileTargetLow = profileManager.currentTargetLow()
                let profileTargetHigh = profileManager.currentTargetHigh()
                var profileTarget: String?

                if let profileTargetLow = profileTargetLow, let profileTargetHigh = profileTargetHigh, profileTargetLow != profileTargetHigh {
                    profileTarget = "\(profileTargetLow) - \(profileTargetHigh)"
                } else if let profileTargetLow = profileTargetLow {
                    profileTarget = profileTargetLow
                }

                if let profileTarget = profileTarget {
                    infoManager.updateInfoData(type: .target, value: profileTarget)
                }

                /*
                 IOB
                 */
                if let insulinMetric = InsulinMetric(from: lastLoopRecord["iob"], key: "iob") {
                    infoManager.updateInfoData(type: .iob, value: insulinMetric)
                    latestIOB = insulinMetric
                }


                /*
                 COB
                 */
                if let cobMetric = CarbMetric(from: lastLoopRecord["cob"], key: "cob") {
                    infoManager.updateInfoData(type: .cob, value: cobMetric)
                    latestCOB = cobMetric
                }

                if let predictdata = lastLoopRecord["predicted"] as? [String:AnyObject] {
                    let prediction = predictdata["values"] as! [Double]
                    PredictionLabel.text = Localizer.toDisplayUnits(String(Int(prediction.last!)))
                    PredictionLabel.textColor = UIColor.systemPurple
                    if UserDefaultsRepository.downloadPrediction.value && latestLoopTime < lastLoopTime {
                        predictionData.removeAll()
                        var predictionTime = lastLoopTime
                        let toLoad = Int(UserDefaultsRepository.predictionToLoad.value * 12)
                        var i = 0
                        while i <= toLoad {
                            if i < prediction.count {
                                let sgvValue = Int(round(prediction[i]))
                                // Skip values higher than 600
                                if sgvValue <= 600 {
                                    let prediction = ShareGlucoseData(sgv: sgvValue, date: predictionTime, direction: "flat")
                                    predictionData.append(prediction)
                                }
                                predictionTime += 300
                            }
                            i += 1
                        }
                        
                        if let predMin = prediction.min(), let predMax = prediction.max() {
                            let formattedMin = Localizer.toDisplayUnits(String(predMin))
                            let formattedMax = Localizer.toDisplayUnits(String(predMax))
                            let value = "\(formattedMin)/\(formattedMax)"
                            infoManager.updateInfoData(type: .minMax, value: value)
                        }

                        updatePredictionGraph()
                    }
                } else {
                    predictionData.removeAll()
                    infoManager.clearInfoData(type: .minMax)
                    updatePredictionGraph()
                }
                if let recBolus = lastLoopRecord["recommendedBolus"] as? Double {
                    let formattedRecBolus = String(format: "%.2fU", recBolus)
                    infoManager.updateInfoData(type: .recBolus, value: formattedRecBolus)
                    UserDefaultsRepository.deviceRecBolus.value = recBolus
                }
                if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String:AnyObject] {
                    if let tempBasalTime = formatter.date(from: (loopStatus["timestamp"] as! String))?.timeIntervalSince1970 {
                        var lastBGTime = lastLoopTime
                        if bgData.count > 0 {
                            lastBGTime = bgData[bgData.count - 1].date
                        }
                        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "tempBasalTime: " + String(tempBasalTime)) }
                        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "lastBGTime: " + String(lastBGTime)) }
                        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "wasEnacted: " + String(wasEnacted)) }
                        if tempBasalTime > lastBGTime && !wasEnacted {
                            LoopStatusLabel.text = "⏀"
                            latestLoopStatusString = "⏀"
                            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Open Loop: recommended temp. temp time > bg time, was not enacted") }
                        } else {
                            LoopStatusLabel.text = "↻"
                            latestLoopStatusString = "↻"
                            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Looping: recommended temp, but temp time is < bg time and/or was enacted") }
                        }
                    }
                } else {
                    LoopStatusLabel.text = "↻"
                    latestLoopStatusString = "↻"
                    if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Looping: no recommended temp") }
                }
                
            }
            
            evaluateNotLooping(lastLoopTime: lastLoopTime)
        }
    }
}
