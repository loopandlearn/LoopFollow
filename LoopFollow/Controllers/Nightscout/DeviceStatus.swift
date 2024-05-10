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
    
    func evaluateNotLooping(lastLoopTime: TimeInterval) {
        if let statusStackView = LoopStatusLabel.superview as? UIStackView {
            if ((TimeInterval(Date().timeIntervalSince1970) - lastLoopTime) / 60) > 15 {
                IsNotLooping = true
                // Change the distribution to 'fill' to allow manual resizing of arranged subviews
                statusStackView.distribution = .fill
                
                // Hide PredictionLabel and expand LoopStatusLabel to fill the entire stack view
                PredictionLabel.isHidden = true
                LoopStatusLabel.frame = CGRect(x: 0, y: 0, width: statusStackView.frame.width, height: statusStackView.frame.height)
                
                // Update LoopStatusLabel's properties to display Not Looping
                LoopStatusLabel.textAlignment = .center
                LoopStatusLabel.text = "⚠️ Not Looping!"
                LoopStatusLabel.textColor = UIColor.systemYellow
                LoopStatusLabel.font = UIFont.boldSystemFont(ofSize: 18)
                
            } else {
                IsNotLooping = false
                // Restore the original distribution and visibility of labels
                statusStackView.distribution = .fillEqually
                PredictionLabel.isHidden = false
                
                // Reset LoopStatusLabel's properties
                LoopStatusLabel.textAlignment = .right
                LoopStatusLabel.font = UIFont.systemFont(ofSize: 17)

                if UserDefaultsRepository.forceDarkMode.value {
                    LoopStatusLabel.textColor = UIColor.white
                } else {
                    LoopStatusLabel.textColor = UIColor.black
                }
            }
        }
        latestLoopTime = lastLoopTime
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
                    tableData[5].value = String(format:"%.0f", reservoirData) + "U"
                } else {
                    latestPumpVolume = 50.0
                    tableData[5].value = "50+U"
                }
                
                if let uploader = lastDeviceStatus?["uploader"] as? [String:AnyObject] {
                    let upbat = uploader["battery"] as! Double
                    tableData[4].value = String(format:"%.0f", upbat) + "%"
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
                        print("Warning: Failed to extract insulinReq from recbolusdata.")
                    }

                    if let autosensdata = lastLoopRecord["enacted"] as? [String:AnyObject] {
                        let sens = autosensdata["sensitivityRatio"] as! Double * 100.0
                        tableData[11].value = String(format:"%.0f", sens) + "%"
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
                        switch graphtype {
                        case "COB": colorName = "LoopYellow"
                        case "UAM": colorName = "UAM"
                        case "IOB": colorName = "Insulin"
                        case "ZT": colorName = "ZT"
                        default: break
                        }

                        if let selectedColor = UIColor(named: colorName) {
                            predictioncolor = selectedColor
                            PredictionLabel.textColor = predictioncolor
                        }

                        let graphdata = predbgdata[graphtype] as! [Double]

                        if let eventualdata = lastLoopRecord["enacted"] as? [String:AnyObject] {
                            if let eventualBGValue = eventualdata["eventualBG"] as? NSNumber {
                                let eventualBGStringValue = String(describing: eventualBGValue)
                                PredictionLabel.text = bgUnits.toDisplayUnits(eventualBGStringValue)
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
                        tableData[9].value = bgUnits.toDisplayUnits(String(predMin!)) + "/" + bgUnits.toDisplayUnits(String(predMax!))

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

                evaluateNotLooping(lastLoopTime: lastLoopTime)
            }
        }
        
        var oText = "" as String
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
        }
        
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
