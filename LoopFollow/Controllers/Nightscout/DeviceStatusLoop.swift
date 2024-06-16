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
        // Check if OpenAPS prediction data exists and clear it if necessary
        let openAPSDataIndices = [12, 13, 14, 15]
        
        for dataIndex in openAPSDataIndices {
            let mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
            let smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
            
            if !mainChart.entries.isEmpty || !smallChart.entries.isEmpty {
                updatePredictionGraphGeneric(
                    dataIndex: dataIndex,
                    predictionData: [],
                    chartLabel: "",
                    color: UIColor.systemGray
                )
            }
        }
        
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
                if let iobdata = lastLoopRecord["iob"] as? [String:AnyObject] {
                    tableData[0].value = String(format:"%.2f", (iobdata["iob"] as! Double))
                    latestIOB = String(format:"%.2f", (iobdata["iob"] as! Double))
                }
                if let cobdata = lastLoopRecord["cob"] as? [String:AnyObject] {
                    tableData[1].value = String(format:"%.0f", cobdata["cob"] as! Double)
                    latestCOB = String(format:"%.0f", cobdata["cob"] as! Double)
                }
                if let predictdata = lastLoopRecord["predicted"] as? [String:AnyObject] {
                    let prediction = predictdata["values"] as! [Double]
                    PredictionLabel.text = bgUnits.toDisplayUnits(String(Int(prediction.last!)))
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
                        
                        let predMin = prediction.min()
                        let predMax = prediction.max()
                        tableData[9].value = bgUnits.toDisplayUnits(String(predMin!)) + "/" + bgUnits.toDisplayUnits(String(predMax!))
                        
                        updatePredictionGraph()
                    }
                } else {
                    predictionData.removeAll()
                    tableData[9].value = ""
                    updatePredictionGraph()
                }
                if let recBolus = lastLoopRecord["recommendedBolus"] as? Double {
                    tableData[8].value = String(format:"%.2fU", recBolus)
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
