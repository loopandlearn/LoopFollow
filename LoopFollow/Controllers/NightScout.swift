//
//  NightScout.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit


extension MainViewController {

    
    //NS Cage Struct
    struct cageData: Codable {
        var created_at: String
    }
    
    //NS Basal Profile Struct
    struct basalProfileStruct: Codable {
        var value: Double
        var time: String
        var timeAsSeconds: Double
    }
    
    //NS Basal Data  Struct
    struct basalGraphStruct: Codable {
        var basalRate: Double
        var date: TimeInterval
    }
    
    //NS Bolus Data  Struct
    struct bolusGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
    }
    
    //NS Bolus Data  Struct
    struct carbGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
        var absorptionTime: Int
    }
    
    func isStaleData() -> Bool {
        if bgData.count > 0 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let lastReadingTime = bgData.last!.date
            let secondsAgo = now - lastReadingTime
            if secondsAgo >= 20*60 {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    
    // Dex Share Web Call
    func webLoadDexShare(onlyPullLastRecord: Bool = false) {
        var count = 288
        if onlyPullLastRecord { count = 1 }
        dexShare?.fetchData(count) { (err, result) -> () in
            
            // TODO: add error checking
            if(err == nil) {
                var data = result!
                self.ProcessNSBGData(data: data, onlyPullLastRecord: onlyPullLastRecord)
            } else {
                // If we get an error, immediately try to pull NS BG Data
                self.webLoadNSBGData(onlyPullLastRecord: onlyPullLastRecord)
                
                if globalVariables.dexVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.dexVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    DispatchQueue.main.async {
                        //self.sendNotification(title: "Dexcom Share Error", body: "Please double check user name and password, internet connection, and sharing status.")
                    }
                }
            }
        }
    }
    
    // NS BG Data Web call
    func webLoadNSBGData(onlyPullLastRecord: Bool = false) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: BG") }
        // Set the count= in the url either to pull 24 hours or only the last record
        var points = "1"
        if !onlyPullLastRecord {
            points = String(self.graphHours * 12 + 1)
        }
        
        // URL processor
        var urlBGDataPath: String = UserDefaultsRepository.url.value + "/api/v1/entries/sgv.json?"
        if token == "" {
            urlBGDataPath = urlBGDataPath + "count=" + points
        } else {
            urlBGDataPath = urlBGDataPath + "token=" + token + "&count=" + points
        }
        guard let urlBGData = URL(string: urlBGDataPath) else {
            if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
            }
            DispatchQueue.main.async {
                if self.bgTimer.isValid {
                    self.bgTimer.invalidate()
                }
                self.startBGTimer(time: 10)
            }
            return
        }
        var request = URLRequest(url: urlBGData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        // Downloader
        let getBGTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.bgTimer.isValid {
                        self.bgTimer.invalidate()
                    }
                    self.startBGTimer(time: 10)
                }
                return
                
            }
            guard let data = data else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.bgTimer.isValid {
                        self.bgTimer.invalidate()
                    }
                    self.startBGTimer(time: 10)
                }
                return
                
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([ShareGlucoseData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    // trigger the processor for the data after downloading.
                    self.ProcessNSBGData(data: entriesResponse, onlyPullLastRecord: onlyPullLastRecord, isNS: true)
                    
                }
            } else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Failure", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.bgTimer.isValid {
                        self.bgTimer.invalidate()
                    }
                    self.startBGTimer(time: 10)
                }
                return
                
            }
        }
        getBGTask.resume()
    }
    
    // NS BG Data Response processor
    func ProcessNSBGData(data: [ShareGlucoseData], onlyPullLastRecord: Bool, isNS: Bool = false){
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG") }
        
        var pullDate = data[data.count - 1].date
        if isNS {
            pullDate = data[data.count - 1].date / 1000
            pullDate.round(FloatingPointRoundingRule.toNearestOrEven)
        }
        
        var latestDate = data[0].date
        if isNS {
            latestDate = data[0].date / 1000
            latestDate.round(FloatingPointRoundingRule.toNearestOrEven)
        }
        
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        if !isNS && (latestDate + 330) < now {
            webLoadNSBGData(onlyPullLastRecord: onlyPullLastRecord)
            print("dex didn't load, triggered NS attempt")
            return
        }
        
        // Start the BG timer based on the reading
        let secondsAgo = now - latestDate
        
        DispatchQueue.main.async {
            // if reading is overdue over: 20:00, re-attempt every 5 minutes
            if secondsAgo >= (20 * 60) {
                self.startBGTimer(time: (5 * 60))
                print("##### started 5 minute bg timer")
                
            // if the reading is overdue: 10:00-19:59, re-attempt every minute
            } else if secondsAgo >= (10 * 60) {
                self.startBGTimer(time: 60)
                print("##### started 1 minute bg timer")
                
            // if the reading is overdue: 7:00-9:59, re-attempt every 30 seconds
            } else if secondsAgo >= (7 * 60) {
                self.startBGTimer(time: 30)
                print("##### started 30 second bg timer")
                
            // if the reading is overdue: 5:00-6:59 re-attempt every 10 seconds
            } else if secondsAgo >= (5 * 60) {
                self.startBGTimer(time: 10)
                print("##### started 10 second bg timer")
            
            // We have a current reading. Set timer to 5:10 from last reading
            } else {
                self.startBGTimer(time: 310 - secondsAgo)
                let timerVal = 310 - secondsAgo
                print("##### started 5:10 bg timer: \(timerVal)")
            }
        }
        
        // If we already have data, we're going to pop it to the end and remove the first. If we have old or no data, we'll destroy the whole array and start over. This is simpler than determining how far back we need to get new data from in case Dex back-filled readings
        if !onlyPullLastRecord {
            bgData.removeAll()
        } else if bgData[bgData.count - 1].date != pullDate {
            bgData.removeFirst()
            if data.count > 0 && UserDefaultsRepository.speakBG.value {
                speakBG(sgv: data[data.count - 1].sgv)
            }
        } else {
            if data.count > 0 {
                self.updateBadge(val: data[data.count - 1].sgv)
            }
            return
        }
        
        // loop through the data so we can reverse the order to oldest first for the graph and convert the NS timestamp to seconds instead of milliseconds. Makes date comparisons easier for everything else.
        for i in 0..<data.count{
            var dateString = data[data.count - 1 - i].date
            if isNS {
                dateString = data[data.count - 1 - i].date / 1000
                dateString.round(FloatingPointRoundingRule.toNearestOrEven)
            }
            if dateString >= dateTimeUtils.getTimeInterval24HoursAgo() {
                let reading = ShareGlucoseData(sgv: data[data.count - 1 - i].sgv, date: dateString, direction: data[data.count - 1 - i].direction)
                bgData.append(reading)
            }
            
        }
        
        viewUpdateNSBG(isNS: isNS)
    }
    
    // NS BG Data Front end updater
    func viewUpdateNSBG (isNS: Bool) {
        DispatchQueue.main.async {
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Display: BG") }
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            let entries = self.bgData
            if entries.count > 0 {
                let latestEntryi = entries.count - 1
                let latestBG = entries[latestEntryi].sgv
                let priorBG = entries[latestEntryi - 1].sgv
                let deltaBG = latestBG - priorBG as Int
                let lastBGTime = entries[latestEntryi].date
                
                let deltaTime = (TimeInterval(Date().timeIntervalSince1970)-lastBGTime) / 60
                var userUnit = " mg/dL"
                if self.mmol {
                    userUnit = " mmol/L"
                }
                
                // TODO: remove testing feature to color code arrow based on NS vs Dex
                if isNS {
                    self.serverText.text = "Nightscout"
                } else {
                    self.serverText.text = "Dexcom"
                }
                
                self.BGText.text = bgUnits.toDisplayUnits(String(latestBG))
                snoozer.BGLabel.text = bgUnits.toDisplayUnits(String(latestBG))
                self.setBGTextColor()
                
                if let directionBG = entries[latestEntryi].direction {
                    self.DirectionText.text = self.bgDirectionGraphic(directionBG)
                    snoozer.DirectionLabel.text = self.bgDirectionGraphic(directionBG)
                    self.latestDirectionString = self.bgDirectionGraphic(directionBG)
                }
                else
                {
                    self.DirectionText.text = ""
                    snoozer.DirectionLabel.text = ""
                    self.latestDirectionString = ""
                }
                
                if deltaBG < 0 {
                    self.DeltaText.text = bgUnits.toDisplayUnits(String(deltaBG))
                    snoozer.DeltaLabel.text = bgUnits.toDisplayUnits(String(deltaBG))
                    self.latestDeltaString = String(deltaBG)
                }
                else
                {
                    self.DeltaText.text = "+" + bgUnits.toDisplayUnits(String(deltaBG))
                    snoozer.DeltaLabel.text = "+" + bgUnits.toDisplayUnits(String(deltaBG))
                    self.latestDeltaString = "+" + String(deltaBG)
                }
                self.updateBadge(val: latestBG)
                
            }
            else
            {
                
                return
            }
            self.updateBGGraph()
            self.updateStats()
        }
        
    }
    
    // NS Device Status Web Call
    func webLoadNSDeviceStatus() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: device status") }
        let urlUser = UserDefaultsRepository.url.value
        
        
        // NS Api is not working to find by greater than date
        var urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?count=288"
        if token != "" {
            urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?count=288&token=" + token
        }
        let escapedAddress = urlStringDeviceStatus.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let urlDeviceStatus = URL(string: escapedAddress!) else {
            if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                //self.sendNotification(title: "Nightscout Failure", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
            }
            DispatchQueue.main.async {
                if self.deviceStatusTimer.isValid {
                    self.deviceStatusTimer.invalidate()
                }
                self.startDeviceStatusTimer(time: 10)
            }
            
            return
        }
        
        
        var requestDeviceStatus = URLRequest(url: urlDeviceStatus)
        requestDeviceStatus.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        
        let deviceStatusTask = URLSession.shared.dataTask(with: requestDeviceStatus) { data, response, error in
            
            guard error == nil else {
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
                return
            }
            
            guard let data = data else {
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
                return
            }
            
            
            let json = try? (JSONSerialization.jsonObject(with: data) as? [[String:AnyObject]])
            if let json = json {
                DispatchQueue.main.async {
                    self.updateDeviceStatusDisplay(jsonDeviceStatus: json)
                }
            } else {
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
                return
            }
        }
        deviceStatusTask.resume()
        
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
                        let prediction = predictdata["values"] as! [Int]
                        PredictionLabel.text = bgUnits.toDisplayUnits(String(Int(prediction.last!)))
                        PredictionLabel.textColor = UIColor.systemPurple
                        if UserDefaultsRepository.downloadPrediction.value && latestLoopTime < lastLoopTime {
                            predictionData.removeAll()
                            var predictionTime = lastLoopTime
                            let toLoad = Int(UserDefaultsRepository.predictionToLoad.value * 12)
                            var i = 0
                            while i <= toLoad {
                                if i < prediction.count {
                                    let prediction = ShareGlucoseData(sgv: prediction[i], date: predictionTime, direction: "flat")
                                    predictionData.append(prediction)
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
        
        var oText = "" as String
        currentOverride = 1.0
        if let lastOverride = lastDeviceStatus?["override"] as! [String : AnyObject]? {
            if let lastOverrideTime = formatter.date(from: (lastOverride["timestamp"] as! String))?.timeIntervalSince1970  {
            }
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
    
    // NS Cage Web Call
    func webLoadNSCage() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: CAGE") }
        let urlUser = UserDefaultsRepository.url.value
        var urlString = urlUser + "/api/v1/treatments.json?find[eventType]=Site%20Change&count=1"
        if token != "" {
            urlString = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType]=Site%20Change&count=1"
        }
        
        guard let urlData = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([cageData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    self.updateCage(data: entriesResponse)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // NS Cage Response Processor
    func updateCage(data: [cageData]) {
        self.clearLastInfoData(index: 7)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: CAGE") }
        if data.count == 0 {
            return
        }
        
        let lastCageString = data[0].created_at
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertCageInsertTime.value = formatter.date(from: (lastCageString))?.timeIntervalSince1970 as! TimeInterval
        if let cageTime = formatter.date(from: (lastCageString))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - cageTime
            //let days = 24 * 60 * 60
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour ] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
            
            let formattedDuration = formatter.string(from: secondsAgo)
            tableData[7].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
    
    // NS Sage Web Call
    func webLoadNSSage() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: SAGE") }
        
        let lastDateString = dateTimeUtils.nowMinus10DaysTimeInterval()
        let urlUser = UserDefaultsRepository.url.value
        var urlString = urlUser + "/api/v1/treatments.json?find[eventType]=Sensor%20Start&find[created_at][$gte]=" + lastDateString + "&count=1"
        if token != "" {
            urlString = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType]=Sensor%20Start&find[created_at][$gte]=" + lastDateString + "&count=1"
        }
        
        guard let urlData = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([cageData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    self.updateSage(data: entriesResponse)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // NS Sage Response Processor
    func updateSage(data: [cageData]) {
        self.clearLastInfoData(index: 6)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process/Display: SAGE") }
        if data.count == 0 {
            return
        }
        
        var lastSageString = data[0].created_at
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertSageInsertTime.value = formatter.date(from: (lastSageString))?.timeIntervalSince1970 as! TimeInterval
        if let sageTime = formatter.date(from: (lastSageString as! String))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - sageTime
            let days = 24 * 60 * 60
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
            
            let formattedDuration = formatter.string(from: secondsAgo)
            tableData[6].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
    
    // NS Profile Web Call
    func webLoadNSProfile() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: profile") }
        let urlUser = UserDefaultsRepository.url.value
        var urlString = urlUser + "/api/v1/profile/current.json"
        if token != "" {
            urlString = urlUser + "/api/v1/profile/current.json?token=" + token
        }
        
        let escapedAddress = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let url = URL(string: escapedAddress!) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            
            let json = try? JSONSerialization.jsonObject(with: data) as! Dictionary<String, Any>
            
            if let json = json {
                DispatchQueue.main.async {
                    self.updateProfile(jsonDeviceStatus: json)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // NS Profile Response Processor
    func updateProfile(jsonDeviceStatus: Dictionary<String, Any>) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: profile") }
        if jsonDeviceStatus.count == 0 {
            return
        }
        if jsonDeviceStatus[keyPath: "message"] != nil { return }
        let basal = try jsonDeviceStatus[keyPath: "store.Default.basal"] as! NSArray
        basalProfile.removeAll()
        for i in 0..<basal.count {
            let dict = basal[i] as! Dictionary<String, Any>
            do {
                let thisValue = try dict[keyPath: "value"] as! Double
                let thisTime = dict[keyPath: "time"] as! String
                let thisTimeAsSeconds = dict[keyPath: "timeAsSeconds"] as! Double
                let entry = basalProfileStruct(value: thisValue, time: thisTime, timeAsSeconds: thisTimeAsSeconds)
                basalProfile.append(entry)
            } catch {
               if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: profile wrapped in quotes") }
            }
        }
        
        
        // Don't process the basal or draw the graph until after the BG has been fully processeed and drawn
        if firstGraphLoad { return }
        
        // Make temporary array with all values of yesterday and today
        let yesterdayStart = dateTimeUtils.getTimeIntervalMidnightYesterday()
        let todayStart = dateTimeUtils.getTimeIntervalMidnightToday()
        
        var basal2Day: [DataStructs.basal2DayProfile] = []
        // Run twice to add in order yesterday then today.
        for p in 0..<basalProfile.count {
            let start = yesterdayStart + basalProfile[p].timeAsSeconds
            var end = yesterdayStart
            // set the endings 1 second before the next one starts
            if p < basalProfile.count - 1 {
                end = yesterdayStart + basalProfile[p + 1].timeAsSeconds - 1
            } else {
                // set the end 1 second before midnight
                end = yesterdayStart + 86399
            }
            let entry = DataStructs.basal2DayProfile(basalRate: basalProfile[p].value, startDate: start, endDate: end)
            basal2Day.append(entry)
        }
        for p in 0..<basalProfile.count {
            let start = todayStart + basalProfile[p].timeAsSeconds
            var end = todayStart
            // set the endings 1 second before the next one starts
            if p < basalProfile.count - 1 {
                end = todayStart + basalProfile[p + 1].timeAsSeconds - 1
            } else {
                // set the end 1 second before midnight
                end = todayStart + 86399
            }
            let entry = DataStructs.basal2DayProfile(basalRate: basalProfile[p].value, startDate: start, endDate: end)
            basal2Day.append(entry)
        }
        
        var firstPass = true
        // Runs the scheduled basal to the end of the prediction line
        var predictionEndTime = dateTimeUtils.getNowTimeIntervalUTC() + (3600 * UserDefaultsRepository.predictionToLoad.value)
        basalScheduleData.removeAll()
        for i in 0..<basal2Day.count {
            let timeYesterday = dateTimeUtils.getTimeInterval24HoursAgo()
            
            
            // This processed everything after the first one.
            if firstPass == false
                && basal2Day[i].startDate <= predictionEndTime {
                let startDot = basalGraphStruct(basalRate: basal2Day[i].basalRate, date: basal2Day[i].startDate)
                basalScheduleData.append(startDot)
                var endDate = basal2Day[i].endDate
                
                // if it's the last one needed, set it to end at the prediction end time
                if endDate > predictionEndTime || i == basal2Day.count - 1 {
                    endDate = Double(predictionEndTime)
                }

                
                


                let endDot = basalGraphStruct(basalRate: basal2Day[i].basalRate, date: endDate)
                basalScheduleData.append(endDot)
            }
            
            // we need to manually set the first one
            // Check that this is the first one and there are no existing entries
            if firstPass == true {
                // check that the timestamp is > the current entry and < the next entry
                if timeYesterday >= basal2Day[i].startDate && timeYesterday < basal2Day[i].endDate {
                    // Set the start time to match the BG start
                    let startDot = basalGraphStruct(basalRate: basal2Day[i].basalRate, date: Double(dateTimeUtils.getTimeInterval24HoursAgo() + (60 * 5)))
                    basalScheduleData.append(startDot)
                    
                    // set the enddot where the next one will start
                    var endDate = basal2Day[i].endDate
                    let endDot = basalGraphStruct(basalRate: basal2Day[i].basalRate, date: endDate)
                    basalScheduleData.append(endDot)
                    firstPass = false
                }
            }
            

            
        }
        
        if UserDefaultsRepository.graphBasal.value {
            updateBasalScheduledGraph()
        }
        
    }
    
    // NS Treatments Web Call
    // Downloads Basal, Bolus, Carbs, BG Check, Notes, Overrides
    func WebLoadNSTreatments() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: Treatments") }
        if !UserDefaultsRepository.downloadTreatments.value { return }
        
        let yesterdayString = dateTimeUtils.nowMinus24HoursTimeInterval()
        
        var urlString = UserDefaultsRepository.url.value + "/api/v1/treatments.json?find[created_at][$gte]=" + yesterdayString
        if token != "" {
            urlString = UserDefaultsRepository.url.value + "/api/v1/treatments.json?token=" + token + "&find[created_at][$gte]=" + yesterdayString
        }
        
        guard let urlData = URL(string: urlString) else {
            return
        }
        
        
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let json = try? (JSONSerialization.jsonObject(with: data) as? [[String:AnyObject]])
            if let json = json {
                DispatchQueue.main.async {
                    self.updateTreatments(entries: json)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // Process and split out treatments to individual tasks
    func updateTreatments(entries: [[String:AnyObject]]) {
        
        var tempBasal: [[String:AnyObject]] = []
        var bolus: [[String:AnyObject]] = []
        var carbs: [[String:AnyObject]] = []
        var temporaryOverride: [[String:AnyObject]] = []
        var note: [[String:AnyObject]] = []
        var bgCheck: [[String:AnyObject]] = []
        var suspendPump: [[String:AnyObject]] = []
        var resumePump: [[String:AnyObject]] = []
        var pumpSiteChange: [[String:AnyObject]] = []
        var cgmSensorStart: [[String:AnyObject]] = []
        
        for i in 0..<entries.count {
            let entry = entries[i] as [String : AnyObject]?
            switch entry?["eventType"] as! String {
                case "Temp Basal":
                    tempBasal.append(entry!)
                case "Correction Bolus":
                    bolus.append(entry!)
                case "Meal Bolus":
                    carbs.append(entry!)
                case "Temporary Override":
                    temporaryOverride.append(entry!)
                case "Note":
                    note.append(entry!)
                    print("Note: \(String(describing: entry))")
                case "BG Check":
                    bgCheck.append(entry!)
                case "Suspend Pump":
                    suspendPump.append(entry!)
                case "Resume Pump":
                    resumePump.append(entry!)
                case "Pump Site Change":
                    pumpSiteChange.append(entry!)
                case "Sensor Start":
                    cgmSensorStart.append(entry!)
                default:
                    print("No Match: \(String(describing: entry))")
            }
        }
        // end of for loop
        
        if tempBasal.count > 0 {
                   processNSBasals(entries: tempBasal)
               } else {
                   if basalData.count < 0 {
                       clearOldTempBasal()
                   }
               }
               if bolus.count > 0 {
                   processNSBolus(entries: bolus)
               } else {
                   if bolusData.count > 0 {
                       clearOldBolus()
                   }
               }
               if carbs.count > 0 {
                   processNSCarbs(entries: carbs)
               } else {
                   if carbData.count > 0 {
                       clearOldCarb()
                   }
               }
               if bgCheck.count > 0 {
                   processNSBGCheck(entries: bgCheck)
               } else {
                   if bgCheckData.count > 0 {
                       clearOldBGCheck()
                   }
               }
               if temporaryOverride.count > 0 {
                   processNSOverrides(entries: temporaryOverride)
               } else {
                   if overrideGraphData.count > 0 {
                       clearOldOverride()
                   }
               }
               if suspendPump.count > 0 {
                   processSuspendPump(entries: suspendPump)
               } else {
                   if suspendGraphData.count > 0 {
                       clearOldSuspend()
                   }
               }
               if resumePump.count > 0 {
                   processResumePump(entries: resumePump)
               } else {
                   if resumeGraphData.count > 0 {
                       clearOldResume()
                   }
               }
               if cgmSensorStart.count > 0 {
                   processSensorStart(entries: cgmSensorStart)
               } else {
                   if sensorStartGraphData.count > 0 {
                       clearOldSensor()
                   }
               }
               if note.count > 0 {
                   processNotes(entries: note)
               } else {
                   if noteGraphData.count > 0 {
                       clearOldNotes()
                   }
               }
    }
    
    func clearOldTempBasal()
        {
            for i in 0..<basalData.count {
                if basalData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    basalData.remove(at: i)
                }
            }
            updateBasalGraph()
        }
        
        func clearOldBolus()
        {
            for i in 0..<bolusData.count {
                if bolusData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    bolusData.remove(at: i)
                }
            }
            updateBolusGraph()
        }
        
        func clearOldCarb()
        {
            for i in 0..<carbData.count {
                if carbData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    carbData.remove(at: i)
                }
            }
            updateCarbGraph()
        }
        
        func clearOldBGCheck()
        {
            for i in 0..<bgCheckData.count {
                if bgCheckData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    bgCheckData.remove(at: i)
                }
            }
            updateBGCheckGraph()
        }
        
        func clearOldOverride()
        {
            for i in 0..<overrideGraphData.count {
                if overrideGraphData[i].endDate < dateTimeUtils.getTimeInterval24HoursAgo() {
                    overrideGraphData.remove(at: i)
                }
            }
            updateOverrideGraph()
        }
        
        func clearOldSuspend()
        {
            for i in 0..<suspendGraphData.count {
                if suspendGraphData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    suspendGraphData.remove(at: i)
                }
            }
            updateSuspendGraph()
        }
        
        func clearOldResume()
        {
            for i in 0..<resumeGraphData.count {
                if resumeGraphData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    resumeGraphData.remove(at: i)
                }
            }
            updateResumeGraph()
        }
        
        func clearOldSensor()
        {
            for i in 0..<sensorStartGraphData.count {
                if sensorStartGraphData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    sensorStartGraphData.remove(at: i)
                }
            }
            updateSensorStart()
        }
        
        func clearOldNotes()
        {
            for i in 0..<noteGraphData.count {
                if noteGraphData[i].date < dateTimeUtils.getTimeInterval24HoursAgo() {
                    noteGraphData.remove(at: i)
                }
            }
            updateNotes()
        }
    
    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String:AnyObject]]) {
        self.clearLastInfoData(index: 2)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Basal") }
        // due to temp basal durations, we're going to destroy the array and load everything each cycle for the time being.
        basalData.removeAll()
        
        var lastEndDot = 0.0
        
        var tempArray = entries
        tempArray.reverse()
        for i in 0..<tempArray.count {
            let currentEntry = tempArray[i] as [String : AnyObject]?
            var basalDate: String
            if currentEntry?["timestamp"] != nil {
                basalDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                basalDate = currentEntry?["created_at"] as! String
            } else {
                return
            }
            var strippedZone = String(basalDate.dropLast())
            strippedZone = strippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970
            guard let basalRate = currentEntry?["absolute"] as? Double else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Null Basal entry")}
                continue
            }
            
            let midnightTime = dateTimeUtils.getTimeIntervalMidnightToday()
            // Setting end dots
            var duration = 0.0
            do {
                duration = try currentEntry?["duration"] as! Double
            } catch {
                print("No Duration Found")
            }
            
            // This adds scheduled basal wherever there is a break between temps. can't check the prior ending on the first item. it is 24 hours old, so it isn't important for display anyway
            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String : AnyObject]?
                var priorBasalDate: String
                if priorEntry?["timestamp"] != nil {
                    priorBasalDate = priorEntry?["timestamp"] as! String
                } else if currentEntry?["created_at"] != nil {
                    priorBasalDate = priorEntry?["created_at"] as! String
                } else {
                    continue
                }
                var priorStrippedZone = String(priorBasalDate.dropLast())
                priorStrippedZone = priorStrippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                let priorDateFormatter = DateFormatter()
                priorDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                priorDateFormatter.locale = Locale(identifier: "en_US")
                priorDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                let priorDateString = dateFormatter.date(from: priorStrippedZone)
                let priorDateTimeStamp = priorDateString!.timeIntervalSince1970
                let priorDuration = priorEntry?["duration"] as! Double
                // if difference between time stamps is greater than the duration of the last entry, there is a gap. Give a 15 second leeway on the timestamp
                if Double( dateTimeStamp - priorDateTimeStamp ) > Double( (priorDuration * 60) + 15 ) {
                    
                    var scheduled = 0.0
                    var midGap = false
                    var midGapTime: TimeInterval = 0
                    var midGapValue: Double = 0
                    // cycle through basal profiles.
                    // TODO figure out how to deal with profile changes that happen mid-gap
                    for b in 0..<self.basalScheduleData.count {
                        
                        if (priorDateTimeStamp + (priorDuration * 60)) >= basalScheduleData[b].date {
                            scheduled = basalScheduleData[b].basalRate
                            
                            // deal with mid-gap scheduled basal change
                            // don't do it on the last scheudled basal entry
                            if b < self.basalScheduleData.count - 1 {
                                if dateTimeStamp > self.basalScheduleData[b + 1].date {
                                   // midGap = true
                                    // TODO: finish this to handle mid-gap items without crashing from overlapping entries
                                    midGapTime = self.basalScheduleData[b + 1].date
                                    midGapValue = self.basalScheduleData[b + 1].basalRate
                                }
                            }
                            
                        }
                        
                    }
                    
                    // Make the starting dot at the last ending dot
                    let startDot = basalGraphStruct(basalRate: scheduled, date: Double(priorDateTimeStamp + (priorDuration * 60)))
                    basalData.append(startDot)
                        
                       
                    if midGap {
                        // Make the ending dot at the new scheduled basal
                        let endDot1 = basalGraphStruct(basalRate: scheduled, date: Double(midGapTime))
                        basalData.append(endDot1)
                        // Make the starting dot at the scheduled Time
                        let startDot2 = basalGraphStruct(basalRate: midGapValue, date: Double(midGapTime))
                        basalData.append(startDot2)
                        // Make the ending dot at the new basal value
                        let endDot2 = basalGraphStruct(basalRate: midGapValue, date: Double(dateTimeStamp))
                        basalData.append(endDot2)
                        
                    } else {
                        // Make the ending dot at the new starting dot
                        let endDot = basalGraphStruct(basalRate: scheduled, date: Double(dateTimeStamp))
                        basalData.append(endDot)
                    }
                        

                }
            }
            
            // Make the starting dot
            let startDot = basalGraphStruct(basalRate: basalRate, date: Double(dateTimeStamp))
            basalData.append(startDot)
            
            // Make the ending dot
            // If it's the last one and has no duration, extend it for 30 minutes past the start. Otherwise set ending at duration
            // duration is already set to 0 if there is no duration set on it.
            //if i == tempArray.count - 1 && dateTimeStamp + duration <= dateTimeUtils.getNowTimeIntervalUTC() {
            if i == tempArray.count - 1 && duration == 0.0 {
                lastEndDot = dateTimeStamp + (30 * 60)
                latestBasal = String(format:"%.2f", basalRate)
            } else {
                lastEndDot = dateTimeStamp + (duration * 60)
                latestBasal = String(format:"%.2f", basalRate)
            }
            
            // Double check for overlaps of incorrectly ended TBRs and sent it to end when the next one starts if it finds a discrepancy
            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String : AnyObject]?
                var nextBasalDate: String
                if nextEntry?["timestamp"] != nil {
                    nextBasalDate = nextEntry?["timestamp"] as! String
                } else if currentEntry?["created_at"] != nil {
                    nextBasalDate = nextEntry?["created_at"] as! String
                } else {
                    continue
                }
                var nextStrippedZone = String(nextBasalDate.dropLast())
                nextStrippedZone = nextStrippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                let nextDateFormatter = DateFormatter()
                nextDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                nextDateFormatter.locale = Locale(identifier: "en_US")
                nextDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                let nextDateString = dateFormatter.date(from: nextStrippedZone)
                let nextDateTimeStamp = nextDateString!.timeIntervalSince1970
                if nextDateTimeStamp < (dateTimeStamp + (duration * 60)) {
                    lastEndDot = nextDateTimeStamp
                }
            }
            
            let endDot = basalGraphStruct(basalRate: basalRate, date: Double(lastEndDot))
            basalData.append(endDot)
            
            
        }
        
        // If last  basal was prior to right now, we need to create one last scheduled entry
        if lastEndDot <= dateTimeUtils.getNowTimeIntervalUTC() {
            var scheduled = 0.0
            // cycle through basal profiles.
            // TODO figure out how to deal with profile changes that happen mid-gap
            for b in 0..<self.basalProfile.count {
                let scheduleTimeYesterday = self.basalProfile[b].timeAsSeconds + dateTimeUtils.getTimeIntervalMidnightYesterday()
                let scheduleTimeToday = self.basalProfile[b].timeAsSeconds + dateTimeUtils.getTimeIntervalMidnightToday()
                // check the prior temp ending to the profile seconds from midnight
                print("yesterday " + String(scheduleTimeYesterday))
                print("today " + String(scheduleTimeToday))
                if lastEndDot >= scheduleTimeToday {
                    scheduled = basalProfile[b].value
                }
            }
            
            latestBasal = String(format:"%.2f", scheduled)
            // Make the starting dot at the last ending dot
            let startDot = basalGraphStruct(basalRate: scheduled, date: Double(lastEndDot))
            basalData.append(startDot)
            
            // Make the ending dot 10 minutes after now
            let endDot = basalGraphStruct(basalRate: scheduled, date: Double(Date().timeIntervalSince1970 + (60 * 10)))
            basalData.append(endDot)
            
        }
        tableData[2].value = latestBasal
        infoTable.reloadData()
        if UserDefaultsRepository.graphBasal.value {
            updateBasalGraph()
        }
        infoTable.reloadData()
    }

    // NS Meal Bolus Response Processor
    func processNSBolus(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Bolus") }
        // because it's a small array, we're going to destroy and reload every time.
        bolusData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var bolusDate: String
            if currentEntry?["timestamp"] != nil {
                bolusDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                bolusDate = currentEntry?["created_at"] as! String
            } else {
                return
            }
            
            // fix to remove millisecond (after period in timestamp) for FreeAPS users
            var strippedZone = String(bolusDate.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

                guard let bolus = currentEntry?["insulin"] as? Double else { continue }
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex
                
                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    // Make the dot
                    let dot = bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
                    bolusData.append(dot)
                }
            
        }
        
        if UserDefaultsRepository.graphBolus.value {
            updateBolusGraph()
        }
        
    }
   
    // NS Carb Bolus Response Processor
    func processNSCarbs(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Carbs") }
        // because it's a small array, we're going to destroy and reload every time.
        carbData.removeAll()
        var lastFoundIndex = 0
        var lastFoundBolus = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var carbDate: String
            if currentEntry?["timestamp"] != nil {
                carbDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                carbDate = currentEntry?["created_at"] as! String
            } else {
                return
            }
            
            
            let absorptionTime = currentEntry?["absorptionTime"] as? Int ?? 0
            
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(carbDate.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            var dateTimeStamp = dateString!.timeIntervalSince1970
            
            guard let carbs = currentEntry?["carbs"] as? Double else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Null Carb entry")}
                break
            }
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            var offset = -50
            if sgv.sgv < Double(topBG - 100) {
                let bolusTime = findNearestBolusbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: bolusData, startingIndex: lastFoundBolus)
                lastFoundBolus = bolusTime.foundIndex
                
                if bolusTime.offset {
                    offset = 70
                } else {
                    offset = 20
                }
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = carbGraphStruct(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv + Double(offset)), absorptionTime: absorptionTime)
                carbData.append(dot)
            }
            
            
            
        }
        
        if UserDefaultsRepository.graphCarbs.value {
            updateCarbGraph()
        }
        
        
    }
    
    // NS Suspend Pump Response Processor
    func processSuspendPump(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Suspend Pump") }
        // because it's a small array, we're going to destroy and reload every time.
        suspendGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                suspendGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateSuspendGraph()
        }
        
    }
    
    // NS Resume Pump Response Processor
    func processResumePump(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Resume Pump") }
        // because it's a small array, we're going to destroy and reload every time.
        resumeGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                resumeGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateResumeGraph()
        }
        
    }
    
    // NS Sensor Start Response Processor
    func processSensorStart(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Sensor Start") }
        // because it's a small array, we're going to destroy and reload every time.
        sensorStartGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                sensorStartGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateSensorStart()
        }
        
    }
    
    // NS Note Response Processor
    func processNotes(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Notes") }
        // because it's a small array, we're going to destroy and reload every time.
        noteGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            guard let thisNote = currentEntry?["notes"] as? String else { continue }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.noteStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv), note: thisNote)
                noteGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateNotes()
        }
        
    }
    
    // NS BG Check Response Processor
    func processNSBGCheck(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG Check") }
        // because it's a small array, we're going to destroy and reload every time.
        bgCheckData.removeAll()
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970
            
            guard let sgv = currentEntry?["glucose"] as? Int else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Non-Int Glucose entry")}
                continue
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                //let dot = ShareGlucoseData(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                let dot = ShareGlucoseData(sgv: sgv, date: Double(dateTimeStamp), direction: "")
                bgCheckData.append(dot)
            }
            
            
            
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateBGCheckGraph()
        }
        
        
    }
    
    // NS Override Response Processor
    func processNSOverrides(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Overrides") }
        // because it's a small array, we're going to destroy and reload every time.
        overrideGraphData.removeAll()
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            var dateTimeStamp = dateString!.timeIntervalSince1970
            if dateTimeStamp < dateTimeUtils.getTimeInterval24HoursAgo() {
                dateTimeStamp = dateTimeUtils.getTimeInterval24HoursAgo()
            }
            
            var multiplier: Double = 1.0
            if currentEntry?["insulinNeedsScaleFactor"] != nil {
                multiplier = currentEntry?["insulinNeedsScaleFactor"] as! Double
            }
            var duration: Double = 5.0
            if let durationType = currentEntry?["durationType"] as? String {
                duration = dateTimeUtils.getNowTimeIntervalUTC() - dateTimeStamp + (60 * 60)
            } else {
                duration = (currentEntry?["duration"] as? Double)!
                duration = duration * 60
            }
            
            guard let enteredBy = currentEntry?["enteredBy"] as? String else { continue }
            guard let reason = currentEntry?["reason"] as? String else { continue }
            
            var range: [Int] = []
            if let ranges = currentEntry?["correctionRange"] as? [Int] {
                if ranges.count == 2 {
                    guard let low = ranges[0] as? Int else { continue }
                    guard let high = ranges[1] as? Int else { continue }
                    range.append(low)
                    range.append(high)
                }
                
            }
                        
            let endDate = dateTimeStamp + (duration)

            let dot = DataStructs.overrideStruct(insulNeedsScaleFactor: multiplier, date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: range, enteredBy: enteredBy, reason: reason, sgv: -20)
            overrideGraphData.append(dot)
            
            
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateOverrideGraph()
        }
        
    }
}
