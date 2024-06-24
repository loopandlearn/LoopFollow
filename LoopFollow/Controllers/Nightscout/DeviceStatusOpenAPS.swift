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
        
        if let lastLoopTime = formatter.date(from: (lastDeviceStatus?["created_at"] as! String))?.timeIntervalSince1970  {
            UserDefaultsRepository.alertLastLoopTime.value = lastLoopTime
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "lastLoopTime: " + String(lastLoopTime)) }
            if lastLoopRecord["failureReason"] != nil {
                LoopStatusLabel.text = "X"
                latestLoopStatusString = "X"
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Loop Failure: X") }
            } else {
                if let iobdata = lastLoopRecord["iob"] as? [String:AnyObject] {
                    tableData[0].value = String(format:"%.2f", (iobdata["iob"] as! Double))
                    latestIOB = String(format:"%.2f", (iobdata["iob"] as! Double))
                }
                if let cobdata = lastLoopRecord["enacted"] as? [String:AnyObject] {
                    tableData[1].value = String(format:"%.0f", cobdata["COB"] as! Double)
                    latestCOB = String(format:"%.0f", cobdata["COB"] as! Double)
                }
                if let recbolusdata = lastLoopRecord["enacted"] as? [String: AnyObject],
                   let insulinReq = recbolusdata["insulinReq"] as? Double {
                    tableData[8].value = String(format: "%.2fU", insulinReq)
                    UserDefaultsRepository.deviceRecBolus.value = insulinReq
                } else {
                    tableData[8].value = "N/A"
                    UserDefaultsRepository.deviceRecBolus.value = 0
                }
                
                if let autosensdata = lastLoopRecord["enacted"] as? [String:AnyObject] {
                    let sens = autosensdata["sensitivityRatio"] as! Double * 100.0
                    tableData[11].value = String(format:"%.0f", sens) + "%"
                }
                
                var predictioncolor = UIColor.systemGray
                PredictionLabel.textColor = predictioncolor
                topPredictionBG = UserDefaultsRepository.minBGScale.value
                if let enactdata = lastLoopRecord["enacted"] as? [String:AnyObject],
                   let predbgdata = enactdata["predBGs"] as? [String: AnyObject] {
                    let predictionTypes: [(type: String, colorName: String, dataIndex: Int)] = [
                        ("ZT", "ZT", 12),
                        ("IOB", "Insulin", 13),
                        ("COB", "LoopYellow", 14),
                        ("UAM", "UAM", 15)
                    ]
                    
                    for (type, colorName, dataIndex) in predictionTypes {
                        var predictionData = [ShareGlucoseData]()
                        if let graphdata = predbgdata[type] as? [Double] {
                            var predictionTime = lastLoopTime
                            let toLoad = Int(UserDefaultsRepository.predictionToLoad.value * 12)
                            
                            for i in 0...toLoad {
                                if i < graphdata.count {
                                    let prediction = ShareGlucoseData(sgv: Int(round(graphdata[i])), date: predictionTime, direction: "flat")
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
                }
            }
        }
    }
}
