//
//  DeviceStatus.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

extension MainViewController {
    // NS Device Status Web Call
    func webLoadNSDeviceStatus() {
        if UserDefaultsRepository.debugLog.value {
            self.writeDebugLog(value: "Download: device status")
        }
        
        let parameters: [String: String] = ["count": "288"]
        NightscoutUtils.executeDynamicRequest(eventType: .deviceStatus, parameters: parameters) { result in
            switch result {
            case .success(let json):
                if let jsonDeviceStatus = json as? [[String: AnyObject]] {
                    DispatchQueue.main.async {
                        self.updateDeviceStatusDisplay(jsonDeviceStatus: jsonDeviceStatus)
                    }
                } else {
                    self.handleDeviceStatusError()
                }
                
            case .failure:
                self.handleDeviceStatusError()
            }
        }
    }
    
    func mgdlToMmol(_ mgdl: Double) -> Double {
        return mgdl * 0.05551
    }
    
    private func handleDeviceStatusError() {
        if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
            globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
            //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
        }
        DispatchQueue.main.async {
            if self.deviceStatusTimer.isValid {
                self.deviceStatusTimer.invalidate()
            }
            self.startDeviceStatusTimer(time: 10)
        }
    }
    
    // NS Device Status Response Processor
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String:AnyObject]]) {
        self.clearLastInfoData(index: 0)
        self.clearLastInfoData(index: 1)
        self.clearLastInfoData(index: 3)
        self.clearLastInfoData(index: 4)
        self.clearLastInfoData(index: 5)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: device status") }
        if jsonDeviceStatus.count == 0 {
            return
        }
        
        //Process the current data first
        let lastDeviceStatus = jsonDeviceStatus[0] as [String : AnyObject]?
        
        //pump and uploader
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        if let lastPumpRecord = lastDeviceStatus?["pump"] as! [String : AnyObject]? {
            if let lastPumpTime = formatter.date(from: (lastPumpRecord["clock"] as! String))?.timeIntervalSince1970  {
                if let reservoirData = lastPumpRecord["reservoir"] as? Double {
                    latestPumpVolume = reservoirData
                    tableData[5].value = String(format:"%.0f", reservoirData) + " E"
                } else {
                    latestPumpVolume = 50.0
                    tableData[5].value = "50+E"
                }
                
                if let uploader = lastDeviceStatus?["uploader"] as? [String:AnyObject] {
                    let upbat = uploader["battery"] as! Double
                    tableData[4].value = String(format:"%.0f", upbat) + " %"
                    UserDefaultsRepository.deviceBatteryLevel.value = upbat
                }
            }
        }
        
        // Loop
        if let lastLoopRecord = lastDeviceStatus?["loop"] as! [String : AnyObject]? {
            //print("Loop: \(lastLoopRecord)")
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
                        tableData[0].value = String(format:"%.2f", (iobdata["iob"] as! Double)) + " E"
                        latestIOB = String(format:"%.2f", (iobdata["iob"] as! Double))
                    }
                    if let cobdata = lastLoopRecord["cob"] as? [String:AnyObject] {
                        tableData[1].value = String(format:"%.0f", cobdata["cob"] as! Double) + " g"
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
                            tableData[9].value = bgUnits.toDisplayUnits(String(predMin!)) + "-" + bgUnits.toDisplayUnits(String(predMax!)) + " mmol/L"
                            
                            updatePredictionGraph()
                        }
                    }
                    if let recBolus = lastLoopRecord["recommendedBolus"] as? Double {
                        tableData[8].value = String(format:"%.2f", recBolus) + " E"
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
                
                if ((TimeInterval(Date().timeIntervalSince1970) - lastLoopTime) / 60) > 15 {
                    LoopStatusLabel.text = "⚠"
                    latestLoopStatusString = "⚠"
                }
                latestLoopTime = lastLoopTime
            } // end lastLoopTime
        } // end lastLoop Record
        
        if let lastLoopRecord = lastDeviceStatus?["openaps"] as! [String : AnyObject]? {
            if let lastLoopTime = formatter.date(from: (lastDeviceStatus?["created_at"] as! String))?.timeIntervalSince1970  {
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
                        tableData[0].value = String(format:"%.2f", (iobdata["iob"] as! Double)) + " E"
                        latestIOB = String(format:"%.2f", (iobdata["iob"] as! Double))
                    }
                    if let enactedData = lastLoopRecord["enacted"] as? [String:AnyObject] {
                        tableData[1].value = String(format:"%.0f", enactedData["COB"] as! Double) + " g"
                        latestCOB = String(format:"%.0f", enactedData["COB"] as! Double) + " g"
                        
                        tableData[8].value = String(format:"%.2f", enactedData["insulinReq"] as! Double) + " E"
                        
                        let sens = enactedData["sensitivityRatio"] as! Double * 100.0
                        tableData[11].value = String(format:"%.0f", sens) + " %"
                        
                        //Auggie - get TDD, ISF, CR, target
                        tableData[13].value = String(format:"%.1f", enactedData["TDD"] as! Double) + " E"
                        tableData[14].value = String(format:"%.1f", enactedData["ISF"] as! Double) + " mmol/L/E"
                        tableData[15].value = String(format:"%.1f", enactedData["CR"] as! Double) + " g/E"
                        
                        //Daniel mmol version of target
                        let currentTargetMgdl = enactedData["current_target"] as! Double
                        let currentTargetMmol = mgdlToMmol(currentTargetMgdl)
                        tableData[16].value = String(format: "%.1f", currentTargetMmol) + " mmol/L"
                        
                    } else {
                        // If enactedData is nil, set all tableData values to "Waiting"
                        for i in 1..<tableData.count {
                            tableData[i].value = "---"
                        }
                        
                    }
                    
                    //Auggie - override name
                    let recentOverride = overrideGraphData.last
                    let overrideName: String?
                    if let notes = recentOverride?.notes, !notes.isEmpty {
                        overrideName = notes
                    } else {
                        overrideName = recentOverride?.reason
                    }
                    let recentEnd: TimeInterval = recentOverride?.endDate ?? 0
                    let now = dateTimeUtils.getNowTimeIntervalUTC()
                    if recentEnd >= now {
                        tableData[3].value = String(overrideName ?? "---")
                    }
                    else {
                        tableData[3].value = "---"
                    }
                    
                    //Picks COB prediction if available, else UAM, else IOB, else ZT
                    //Ideal is to predict all 4 in Loop Follow but this is a quick start
                    var graphtype = ""
                    var predictioncolor = UIColor.systemGray
                    PredictionLabel.textColor = predictioncolor
                    
                    if let enactdata = lastLoopRecord["enacted"] as? [String:AnyObject],
                       let predbgdata = enactdata["predBGs"] as? [String:AnyObject] {
                        
                        if predbgdata["COB"] != nil {
                            graphtype = "COB"
                        } else if predbgdata["UAM"] != nil {
                            graphtype = "UAM"
                        } else if predbgdata["IOB"] != nil {
                            graphtype = "IOB"
                        } else {
                            graphtype = "ZT"
                        }
                        
                        // Access the color based on graphtype
                        var colorName = ""
                        var additionalText = ""
                        
                        switch graphtype {
                        case "COB":
                            colorName = "LoopYellow"
                            additionalText = "COB"
                        case "UAM":
                            colorName = "UAM"
                            additionalText = "UAM"
                        case "IOB":
                            colorName = "Insulin"
                            additionalText = "IOB"
                        case "ZT":
                            colorName = "ZT"
                            additionalText = "ZT"
                        default:
                            break
                        }
                        
                        if let selectedColor = UIColor(named: colorName) {
                            predictioncolor = selectedColor
                            PredictionLabel.textColor = predictioncolor
                        }
                        
                        let graphdata = predbgdata[graphtype] as! [Double]
                        
                        if let eventualdata = lastLoopRecord["enacted"] as? [String: AnyObject] {
                            if let eventualBGValue = eventualdata["eventualBG"] as? NSNumber {
                                let eventualBGStringValue = String(describing: eventualBGValue)
                                let formattedBGString = bgUnits.toDisplayUnits(eventualBGStringValue)
                                PredictionLabel.text = "\(additionalText) ⇢ \(formattedBGString)"
                            }
                        }
                        
                        if UserDefaultsRepository.downloadPrediction.value && latestLoopTime < lastLoopTime {
                            predictionData.removeAll()
                            var predictionTime = lastLoopTime
                            let toLoad = Int(UserDefaultsRepository.predictionToLoad.value * 12)
                            var i = 0
                            while i <= toLoad {
                                if i < graphdata.count {
                                    let prediction = ShareGlucoseData(sgv: Int(round(graphdata[i])), date: predictionTime, direction: "flat")
                                    predictionData.append(prediction)
                                    predictionTime += 300
                                }
                                i += 1
                            }
                        }
                        
                        let predMin = graphdata.min()
                        let predMax = graphdata.max()
                        tableData[9].value = bgUnits.toDisplayUnits(String(predMin!)) + "-" + bgUnits.toDisplayUnits(String(predMax!)) + " mmol/L"
                        
                        updatePredictionGraph(color: predictioncolor)
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
                if ((TimeInterval(Date().timeIntervalSince1970) - lastLoopTime) / 60) > 15 {
                    LoopStatusLabel.text = "⚠"
                    latestLoopStatusString = "⚠"
                }
                latestLoopTime = lastLoopTime
            }
        }
        
        /*var oText = "" as String
        currentOverride = 1.0
        if let lastOverride = lastDeviceStatus?["override"] as! [String : AnyObject]? {
            if lastOverride["active"] as! Bool {
                
                let lastCorrection  = lastOverride["currentCorrectionRange"] as! [String: AnyObject]
                if let multiplier = lastOverride["multiplier"] as? Double {
                    currentOverride = multiplier
                    oText += String(format: "%.0f%%", (multiplier * 100))
                }
                else
                {
                    oText += "100%"
                }
                oText += " ("
                let minValue = lastCorrection["minValue"] as! Double
                let maxValue = lastCorrection["maxValue"] as! Double
                oText += bgUnits.toDisplayUnits(String(minValue)) + "-" + bgUnits.toDisplayUnits(String(maxValue)) + ")"
                
                tableData[3].value =  oText
            }
        }*/
        
        infoTable.reloadData()
        
        // Start the timer based on the timestamp
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        let secondsAgo = now - latestLoopTime
        
        DispatchQueue.main.async {
            // if Loop is overdue over: 20:00, re-attempt every 5 minutes
            if secondsAgo >= (20 * 60) {
                self.startDeviceStatusTimer(time: (5 * 60))
                print("started 5 minute device status timer")
                
                // if the Loop is overdue: 10:00-19:59, re-attempt every minute
            } else if secondsAgo >= (10 * 60) {
                self.startDeviceStatusTimer(time: 60)
                print("started 1 minute device status timer")
                
                // if the Loop is overdue: 7:00-9:59, re-attempt every 30 seconds
            } else if secondsAgo >= (7 * 60) {
                self.startDeviceStatusTimer(time: 30)
                print("started 30 second device status timer")
                
                // if the Loop is overdue: 5:00-6:59 re-attempt every 10 seconds
            } else if secondsAgo >= (5 * 60) {
                self.startDeviceStatusTimer(time: 10)
                print("started 10 second device status timer")
                
                // We have a current Loop. Set timer to 5:10 from last reading
            } else {
                self.startDeviceStatusTimer(time: 310 - secondsAgo)
                let timerVal = 310 - secondsAgo
                print("started 5:10 device status timer: \(timerVal)")
            }
        }
    }
}
