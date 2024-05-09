//
//  DeviceStatus.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

var sharedCRValue: String = ""
var sharedLatestIOB: String = ""
var sharedLatestCOB: String = ""
var sharedMinGuardBG: Double = 0.0
var sharedInsulinReq: Double = 0.0
var sharedLastSMBUnits: Double = 0.0

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
                            // Handle lastTempBasal if needed
                        }
                    }

                    if let iobdata = lastLoopRecord["iob"] as? [String:AnyObject] {
                        if let iob = iobdata["iob"] as? Double {
                            tableData[0].value = String(format:"%.2f", iob) + " E"
                            latestIOB = String(format:"%.2f", iob)
                            sharedLatestIOB = latestIOB
                        }
                    }

                    /*
                    if let enactedData = lastLoopRecord["enacted"] as? [String:AnyObject] {
                        if let COB = enactedData["COB"] as? Double {
                            tableData[1].value = String(format:"%.0f", COB) + " g"
                            latestCOB = String(format:"%.0f", COB)
                            sharedLatestCOB = latestCOB
                        }
                        
                        if let insulinReq = enactedData["insulinReq"] as? Double {
                            tableData[8].value = String(format:"%.2f", insulinReq) + " E"
                        }
                        
                        if let sensitivityRatio = enactedData["sensitivityRatio"] as? Double {
                            let sens = sensitivityRatio * 100.0
                            tableData[11].value = String(format:"%.0f", sens) + " %"
                        }
                        
                        if let TDD = enactedData["TDD"] as? Double {
                            tableData[13].value = String(format:"%.1f", TDD) + " E"
                        }
                        
                        if let ISF = enactedData["ISF"] as? Double {
                            tableData[14].value = String(format:"%.1f", ISF) + " mmol/L/E"
                        }
                        
                        if let CR = enactedData["CR"] as? Double {
                            tableData[15].value = String(format:"%.1f", CR) + " g/E"
                            sharedCRValue = String(format:"%.1f", CR)
                        }
                        
                        if let currentTargetMgdl = enactedData["current_target"] as? Double {
                            let currentTargetMmol = mgdlToMmol(currentTargetMgdl)
                            tableData[16].value = String(format: "%.1f", currentTargetMmol) + " mmol/L"
                        }
                        //Daniel: Added enacted data for bolus calculator and info
                        if let minGuardBG = enactedData["minGuardBG"] as? Double {
                                let formattedMinGuardBGString = bgUnits.toDisplayUnits(String(format:"%.1f", minGuardBG))
                                sharedMinGuardBG = Double(formattedMinGuardBGString) ?? 0
                            } else {
                                let formattedLowLine = bgUnits.toDisplayUnits(String(format:"%.1f", UserDefaultsRepository.lowLine.value))
                                sharedMinGuardBG = Double(formattedLowLine) ?? 0
                            }
                        
                        if let insulinReq = enactedData["insulinReq"] as? Double {
                                let formattedInsulinReqString = String(format:"%.2f", insulinReq)
                                sharedInsulinReq = Double(formattedInsulinReqString) ?? 0
                            } else {
                                sharedInsulinReq = 0
                            }
                        
                        if let LastSMBUnits = enactedData["units"] as? Double {
                                let formattedLastSMBUnitsString = String(format:"%.2f", LastSMBUnits)
                                sharedLastSMBUnits = Double(formattedLastSMBUnitsString) ?? 0
                            } else {
                                sharedLastSMBUnits = 0
                            }
                        
                    } else {
                        // If enactedData is nil, set all tableData values to "Waiting"
                        for i in 1..<tableData.count {
                            tableData[i].value = "---"
                        }
                        
                    }
                     */
                    //Daniel: Use suggested instead of enacted to populate infotable even when not enacted
                    if let suggestedData = lastLoopRecord["suggested"] as? [String:AnyObject] {
                        if let COB = suggestedData["COB"] as? Double {
                            tableData[1].value = String(format:"%.0f", COB) + " g"
                            latestCOB = String(format:"%.0f", COB)
                            sharedLatestCOB = latestCOB
                        }
                        
                        /*if let insulinReq = suggestedData["insulinReq"] as? Double {
                            tableData[8].value = String(format:"%.2f", insulinReq) + " E"
                         }*/
                        if let recbolusdata = lastLoopRecord["suggested"] as? [String: AnyObject],
                           let insulinReq = recbolusdata["insulinReq"] as? Double {
                            tableData[8].value = String(format: "%.2f", insulinReq) + " E"
                            UserDefaultsRepository.deviceRecBolus.value = insulinReq
                        } else {
                            tableData[8].value = "---"
                            UserDefaultsRepository.deviceRecBolus.value = 0
                            print("Warning: Failed to extract insulinReq from recbolusdata.")
                        }
                        
                        if let sensitivityRatio = suggestedData["sensitivityRatio"] as? Double {
                            let sens = sensitivityRatio * 100.0
                            tableData[11].value = String(format:"%.0f", sens) + " %"
                        }
                        
                        if let TDD = suggestedData["TDD"] as? Double {
                            tableData[13].value = String(format:"%.1f", TDD) + " E"
                        }
                        
                        if let ISF = suggestedData["ISF"] as? Double {
                            tableData[14].value = String(format:"%.1f", ISF) + " mmol/L/E"
                        }
                        
                        if let CR = suggestedData["CR"] as? Double {
                            tableData[15].value = String(format:"%.1f", CR) + " g/E"
                            sharedCRValue = String(format:"%.1f", CR)
                        }
                        
                        if let currentTargetMgdl = suggestedData["current_target"] as? Double {
                            let currentTargetMmol = mgdlToMmol(currentTargetMgdl)
                            tableData[16].value = String(format: "%.1f", currentTargetMmol) + " mmol/L"
                        }
                        
                        if let carbsReq = suggestedData["carbsReq"] as? Double {
                            tableData[17].value = String(format:"%.0f", carbsReq) + " g"
                        } else {
                            // If "carbsReq" is not present in suggestedData, set it to 0
                            tableData[17].value = "0 g"
                        }
                        
                        //Daniel: Added suggested data for bolus calculator and info
                        if let minGuardBG = suggestedData["minGuardBG"] as? Double {
                                let formattedMinGuardBGString = bgUnits.toDisplayUnits(String(format:"%.1f", minGuardBG))
                                sharedMinGuardBG = Double(formattedMinGuardBGString) ?? 0
                            } else {
                                let formattedLowLine = bgUnits.toDisplayUnits(String(format:"%.1f", UserDefaultsRepository.lowLine.value))
                                sharedMinGuardBG = Double(formattedLowLine) ?? 0
                            }
                        
                        if let insulinReq = suggestedData["insulinReq"] as? Double {
                                let formattedInsulinReqString = String(format:"%.2f", insulinReq)
                                sharedInsulinReq = Double(formattedInsulinReqString) ?? 0
                            } else {
                                sharedInsulinReq = 0
                            }
                        
                        if let LastSMBUnits = suggestedData["units"] as? Double {
                                let formattedLastSMBUnitsString = String(format:"%.2f", LastSMBUnits)
                                sharedLastSMBUnits = Double(formattedLastSMBUnitsString) ?? 0
                            } else {
                                sharedLastSMBUnits = 0
                            }
                        
                    } else {
                        // If suggestedData is nil, set all tableData values to "Waiting"
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
                        tableData[3].value = String(overrideName ?? "Normal profil")
                    } else {
                        tableData[3].value = "Normal profil"
                    }
                    
                    //Picks COB prediction if available, else UAM, else IOB, else ZT
                    //Ideal is to predict all 4 in Loop Follow but this is a quick start
                    var graphtype = ""
                    var predictioncolor = UIColor.systemGray
                    PredictionLabel.textColor = predictioncolor
                    
                    if let enactdata = lastLoopRecord["suggested"] as? [String:AnyObject],
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
                        
                        if let eventualdata = lastLoopRecord["suggested"] as? [String: AnyObject] {
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
                        
                        if let predMin = graphdata.min(), let predMax = graphdata.max() {
                            let formattedPredMin = bgUnits.toDisplayUnits(String(predMin))
                            let formattedPredMax = bgUnits.toDisplayUnits(String(predMax))
                            tableData[9].value = "\(formattedPredMin) - \(formattedPredMax) mmol/L"
                            updatePredictionGraph(color: predictioncolor)
                        } else {
                            tableData[9].value = "N/A"
                            // Handle the case where predMin or predMax is nil
                        }
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
