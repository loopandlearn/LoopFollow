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
                
                if let iobdata = lastLoopRecord["iob"] as? [String: AnyObject] {
                    tableData[0].value = String(format: "%.2f", (iobdata["iob"] as! Double))
                    latestIOB = String(format: "%.2f", (iobdata["iob"] as! Double))
                }
                if let cobdata = lastLoopRecord["enacted"] as? [String: AnyObject] {
                    tableData[1].value = String(format: "%.0f", cobdata["COB"] as! Double)
                    latestCOB = String(format: "%.0f", cobdata["COB"] as! Double)
                }
                if let recbolusdata = lastLoopRecord["enacted"] as? [String: AnyObject],
                   let insulinReq = recbolusdata["insulinReq"] as? Double {
                    tableData[8].value = String(format: "%.2fU", insulinReq)
                    UserDefaultsRepository.deviceRecBolus.value = insulinReq
                } else {
                    tableData[8].value = "N/A"
                    UserDefaultsRepository.deviceRecBolus.value = 0
                }
                
                if let autosensdata = lastLoopRecord["enacted"] as? [String: AnyObject] {
                    let sens = autosensdata["sensitivityRatio"] as! Double * 100.0
                    tableData[11].value = String(format: "%.0f", sens) + "%"
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
                        ("UAM", "UAM", 15),
                        ("COB", "LoopYellow", 14)
                    ]
                    
                    var minPredBG = Double.infinity
                    var maxPredBG = -Double.infinity
                    var selectedPredictionType: (type: String, colorName: String, dataIndex: Int)?
                    
                    if UserDefaultsRepository.simplifiedTrioPrediction.value {
                        // Simplified mode: determine which prediction type to use
                        for (type, _, _) in predictionTypes.reversed() {
                            if let _ = predbgdata[type] {
                                selectedPredictionType = predictionTypes.first { $0.type == type }
                                break
                            }
                        }
                    }
                    
                    for (type, colorName, dataIndex) in predictionTypes {
                        if let simplifiedType = selectedPredictionType, simplifiedType.type != type {
                            continue
                        }
                        
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
                        tableData[9].value = "\(bgUnits.toDisplayUnits(String(minPredBG)))/\(bgUnits.toDisplayUnits(String(maxPredBG)))"
                    } else {
                        tableData[9].value = "N/A"
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
