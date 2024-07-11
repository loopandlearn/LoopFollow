//
//  DeviceStatusOpenAPS.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-05-19.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

extension MainViewController {
    func DeviceStatusOpenAPS(formatter: ISO8601DateFormatter, lastDeviceStatus: [String: AnyObject]?, lastLoopRecord: [String: AnyObject]) {
        
        if let lastLoopTime = formatter.date(from: (lastDeviceStatus?["created_at"] as! String))?.timeIntervalSince1970 {
            UserDefaultsRepository.alertLastLoopTime.value = lastLoopTime
            if lastLoopRecord["failureReason"] != nil {
                LoopStatusLabel.text = "X"
                latestLoopStatusString = "X"
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Loop Failure: X") }
            } else {
                var wasEnacted = false
                if let enacted = lastLoopRecord["enacted"] as? [String: AnyObject] {
                    wasEnacted = true
                }
                
                if let iobdata = lastLoopRecord["iob"] as? [String: AnyObject],
                   let iobValue = iobdata["iob"] as? Double {
                    let formattedIOB = String(format: "%.2f", iobValue)
                    infoManager.updateInfoData(type: .iob, value: formattedIOB)
                    latestIOB = formattedIOB
                }

                if let cobdata = lastLoopRecord["enacted"] as? [String: AnyObject],
                   let cobValue = cobdata["COB"] as? Double {
                    let formattedCOB = String(format: "%.0f", cobValue)
                    infoManager.updateInfoData(type: .cob, value: formattedCOB)
                    latestCOB = formattedCOB
                }

                if let recbolusdata = lastLoopRecord["enacted"] as? [String: AnyObject],
                   let insulinReq = recbolusdata["insulinReq"] as? Double {
                    let formattedRecBolus = String(format: "%.2fU", insulinReq)
                    infoManager.updateInfoData(type: .recBolus, value: formattedRecBolus)
                    UserDefaultsRepository.deviceRecBolus.value = insulinReq
                } else {
                    infoManager.updateInfoData(type: .recBolus, value: "N/A")
                    UserDefaultsRepository.deviceRecBolus.value = 0
                }

                if let autosensdata = lastLoopRecord["enacted"] as? [String: AnyObject],
                   let sens = autosensdata["sensitivityRatio"] as? Double {
                    let formattedSens = String(format: "%.0f", sens * 100.0) + "%"
                    infoManager.updateInfoData(type: .autosens, value: formattedSens)
                }

                if let eventualdata = lastLoopRecord["enacted"] as? [String: AnyObject] {
                    if let eventualBGValue = eventualdata["eventualBG"] as? NSNumber {
                        let eventualBGStringValue = String(describing: eventualBGValue)
                        PredictionLabel.text = bgUnits.toDisplayUnits(eventualBGStringValue)
                    }
                }
                
                var predictioncolor = UIColor.systemGray
                PredictionLabel.textColor = predictioncolor
                topPredictionBG = UserDefaultsRepository.minBGScale.value
                if let enactdata = lastLoopRecord["enacted"] as? [String: AnyObject],
                   let predbgdata = enactdata["predBGs"] as? [String: AnyObject] {
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
                        let value = "\(bgUnits.toDisplayUnits(String(minPredBG)))/\(bgUnits.toDisplayUnits(String(maxPredBG)))"
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
