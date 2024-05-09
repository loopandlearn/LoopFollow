//
//  BGData.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

var sharedDeltaBG: Int = 0

extension MainViewController {
    // Dex Share Web Call
    func webLoadDexShare() {
        // Dexcom Share only returns 24 hrs of data as of now
        // Requesting more just for consistency with NS
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        let count = graphHours * 12
        dexShare?.fetchData(count) { (err, result) -> () in
            
            // TODO: add error checking
            if(err == nil) {
                let data = result!
                
                // If Dex data is old, load from NS instead
                let latestDate = data[0].date
                let now = dateTimeUtils.getNowTimeIntervalUTC()
                if (latestDate + 330) < now && UserDefaultsRepository.url.value != "" {
                    self.webLoadNSBGData()
                    print("dex didn't load, triggered NS attempt")
                    return
                }
                
                // Dexcom only returns 24 hrs of data. If we need more, call NS.
                if graphHours > 24 && UserDefaultsRepository.url.value != "" {
                    self.webLoadNSBGData(dexData: data)
                } else {
                    self.ProcessDexBGData(data: data, sourceName: "Dexcom")
                }
            } else {
                // If we get an error, immediately try to pull NS BG Data
                if UserDefaultsRepository.url.value != "" {
                    self.webLoadNSBGData()
                }
                
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
    func webLoadNSBGData(dexData: [ShareGlucoseData] = []) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: BG") }
        
        // This kicks it out in the instance where dexcom fails but they aren't using NS &&
        if UserDefaultsRepository.url.value == "" {
            self.startBGTimer(time: 10)
            return
        }
        
        var parameters: [String: String] = [:]
        let utcISODateFormatter = ISO8601DateFormatter()
        let date = Calendar.current.date(byAdding: .day, value: -1 * UserDefaultsRepository.downloadDays.value, to: Date())!
        parameters["count"] = "1200" //increased from 1000 to 1200 to allow 48h of bg data when 2 bg uploaders are used in NS (Dexcom and iAPS for instance = 576 readings/day, 1152 during 48h)
        parameters["find[dateString][$gte]"] = utcISODateFormatter.string(from: date)
        
        NightscoutUtils.executeRequest(eventType: .sgv, parameters: parameters) { (result: Result<[ShareGlucoseData], Error>) in
            switch result {
            case .success(let entriesResponse):
                var nsData = entriesResponse
                DispatchQueue.main.async {
                    // transform NS data to look like Dex data
                    for i in 0..<nsData.count {
                        // convert the NS timestamp to seconds instead of milliseconds
                        nsData[i].date /= 1000
                        nsData[i].date.round(FloatingPointRoundingRule.toNearestOrEven)
                    }
                    print(nsData.count)
                    
                    //Avoid duplicate entries messing up the graph, only use one reading per 5 minutes.
                    let graphHours = 24 * UserDefaultsRepository.downloadDays.value
                    let points = graphHours * 12 + 1
                    var nsData2 = [ShareGlucoseData]()
                    let timestamp = Date().timeIntervalSince1970
                    for i in 0..<points {
                        //Starting with "now" and then step 5 minutes back in time
                        let target = timestamp - Double(i) * 60 * 5
                        //Find the reading closest to the target, but not too far away
                        let closest = nsData.filter{ abs($0.date - target) < 3 * 60 }.min { abs($0.date - target) < abs($1.date - target) }
                        //If a reading is found, add it to the new array
                        if let item = closest {
                            nsData2.append(item)
                        }
                    }
                    print(nsData2.count)
                    
                    // merge NS and Dex data if needed; use recent Dex data and older NS data
                    var sourceName = "Nightscout"
                    if !dexData.isEmpty {
                        let oldestDexDate = dexData[dexData.count - 1].date
                        var itemsToRemove = 0
                        while itemsToRemove < nsData2.count && nsData2[itemsToRemove].date >= oldestDexDate {
                            itemsToRemove += 1
                        }
                        nsData2.removeFirst(itemsToRemove)
                        nsData2 = dexData + nsData2
                        sourceName = "Dexcom"
                    }
                    // trigger the processor for the data after downloading.
                    self.ProcessDexBGData(data: nsData2, sourceName: sourceName)
                }
            case .failure(let error):
                print("Failed to fetch data: \(error)")
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
                // if we have Dex data, use it
                if !dexData.isEmpty {
                    self.ProcessDexBGData(data: dexData, sourceName: "Dexcom")
                }
                return
            }
        }
    }
    
    // Dexcom BG Data Response processor
    func ProcessDexBGData(data: [ShareGlucoseData], sourceName: String){
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG") }
        
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        
        if data.count == 0 {
            return
        }
        let pullDate = data[data.count - 1].date
        let latestDate = data[0].date
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        
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
                self.startBGTimer(time: 300 - secondsAgo + Double(UserDefaultsRepository.bgUpdateDelay.value))
                let timerVal = 310 - secondsAgo
                print("##### started 5:10 bg timer: \(timerVal)")
                if data.count > 1 {
                    self.evaluateSpeakConditions(currentValue: data[0].sgv, previousValue: data[1].sgv)
                }
            }
        }
        
        bgData.removeAll()
        
        // loop through the data so we can reverse the order to oldest first for the graph
        for i in 0..<data.count {
            let dateString = data[data.count - 1 - i].date
            if dateString >= dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                let sgvValue = data[data.count - 1 - i].sgv
                
                // Skip the current iteration if the sgv value is over 600
                // First time a user starts a G7, they get a value of 4000
                if sgvValue > 600 {
                    continue
                }
                
                let reading = ShareGlucoseData(sgv: sgvValue, date: dateString, direction: data[data.count - 1 - i].direction)
                bgData.append(reading)
            }
        }
        
        viewUpdateNSBG(sourceName: sourceName)
    }
    
    func updateServerText(with serverText: String? = nil) {
        if UserDefaultsRepository.showDisplayName.value, let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            self.serverText.text = displayName
        } else if let serverText = serverText {
            self.serverText.text = serverText
        }
    }
    
    // NS BG Data Front end updater
    func viewUpdateNSBG(sourceName: String) {
        DispatchQueue.main.async {
            if UserDefaultsRepository.debugLog.value {
                self.writeDebugLog(value: "Display: BG")
                self.writeDebugLog(value: "Num BG: " + self.bgData.count.description)
            }
            
            let entries = self.bgData
            if entries.count < 2 { return } // Protect index out of bounds
            
            self.updateBGGraph()
            self.updateStats()
            
            let latestEntryIndex = entries.count - 1
            let latestBG = entries[latestEntryIndex].sgv
            let priorBG = entries[latestEntryIndex - 1].sgv
            let deltaBG = latestBG - priorBG
            sharedDeltaBG = deltaBG
            let lastBGTime = entries[latestEntryIndex].date
            
            let deltaTime = (TimeInterval(Date().timeIntervalSince1970) - lastBGTime) / 60
            var userUnit = " mg/dL"
            if self.mmol {
                userUnit = " mmol/L"
            }
            
            self.updateServerText(with: sourceName)
            
            var snoozerBG = ""
            var snoozerDirection = ""
            var snoozerDelta = ""
            
            // Set BGText with the latest BG value
            self.BGText.text = bgUnits.toDisplayUnits(String(latestBG))
            snoozerBG = bgUnits.toDisplayUnits(String(latestBG))
            self.setBGTextColor()
            
            // Direction handling
            if let directionBG = entries[latestEntryIndex].direction {
                self.DirectionText.text = self.bgDirectionGraphic(directionBG)
                snoozerDirection = self.bgDirectionGraphic(directionBG)
                self.latestDirectionString = self.bgDirectionGraphic(directionBG)
            } else {
                self.DirectionText.text = ""
                snoozerDirection = ""
                self.latestDirectionString = ""
            }
            
            // Delta handling
            if deltaBG < 0 {
                self.DeltaText.text = bgUnits.toDisplayUnits(String(deltaBG))
                snoozerDelta = bgUnits.toDisplayUnits(String(deltaBG))
                self.latestDeltaString = String(deltaBG)
            } else {
                self.DeltaText.text = "+" + bgUnits.toDisplayUnits(String(deltaBG))
                snoozerDelta = "+" + bgUnits.toDisplayUnits(String(deltaBG))
                self.latestDeltaString = "+" + String(deltaBG)
            }
            
            // Apply strikethrough to BGText based on the staleness of the data
            let bgTextStr = self.BGText.text ?? ""
            let attributeString = NSMutableAttributedString(string: bgTextStr)
            attributeString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributeString.length))
            if deltaTime >= 12 { // Data is stale
                attributeString.addAttribute(.strikethroughColor, value: UIColor.systemRed, range: NSRange(location: 0, length: attributeString.length))
                self.updateBadge(val: 0)
            } else { // Data is fresh
                attributeString.addAttribute(.strikethroughColor, value: UIColor.clear, range: NSRange(location: 0, length: attributeString.length))
                self.updateBadge(val: latestBG)
            }
            self.BGText.attributedText = attributeString
            
            // Snoozer Display
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.BGLabel.text = snoozerBG
            snoozer.DirectionLabel.text = snoozerDirection
            snoozer.DeltaLabel.text = snoozerDelta
        }
    }
}
