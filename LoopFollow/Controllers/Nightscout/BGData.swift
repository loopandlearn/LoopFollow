//
//  BGData.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-05.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
extension MainViewController {
    // Dex Share Web Call
    func webLoadDexShare() {
        // Dexcom Share only returns 24 hrs of data as of now
        // Requesting more just for consistency with NS
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        let count = graphHours * 12
        dexShare?.fetchData(count) { (err, result) -> () in
            
            if let error = err {
                LogManager.shared.log(category: .dexcom, message: "Error fetching Dexcom data: \(error.localizedDescription)", limitIdentifier: "Error fetching Dexcom data")
                self.webLoadNSBGData()
                return
            }
            
            guard let data = result else {
                LogManager.shared.log(category: .dexcom, message: "Received nil data from Dexcom", limitIdentifier: "Received nil data from Dexcom")
                self.webLoadNSBGData()
                return
            }
            
            // If Dex data is old, load from NS instead
            let latestDate = data[0].date
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            if (latestDate + 330) < now && IsNightscoutEnabled() {
                LogManager.shared.log(category: .dexcom, message: "Dexcom data is old, loading from NS instead", limitIdentifier: "Dexcom data is old, loading from NS instead")
                self.webLoadNSBGData()
                return
            }
            
            // Dexcom only returns 24 hrs of data. If we need more, call NS.
            if graphHours > 24 && IsNightscoutEnabled() {
                self.webLoadNSBGData(dexData: data)
            } else {
                self.ProcessDexBGData(data: data, sourceName: "Dexcom")
            }
        }
    }

    // NS BG Data Web call
    func webLoadNSBGData(dexData: [ShareGlucoseData] = []) {
        // This kicks it out in the instance where dexcom fails but they aren't using NS &&
        if !IsNightscoutEnabled() {
            return
        }

        var parameters: [String: String] = [:]
        let utcISODateFormatter = ISO8601DateFormatter()
        let date = Calendar.current.date(byAdding: .day, value: -1 * UserDefaultsRepository.downloadDays.value, to: Date())!
        parameters["count"] = "\(UserDefaultsRepository.downloadDays.value * 2 * 24 * 60 / 5)"
        parameters["find[dateString][$gte]"] = utcISODateFormatter.string(from: date)

        // Exclude 'cal' entries
        parameters["find[type][$ne]"] = "cal"
        
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

                    var nsData2: [ShareGlucoseData] = []
                    var lastAddedTime = Double.infinity
                    var lastAddedSGV: Int? = nil
                    let minInterval: Double = 30

                    for reading in nsData {
                        if (lastAddedSGV == nil || lastAddedSGV != reading.sgv) || (lastAddedTime - reading.date >= minInterval) {
                            nsData2.append(reading)
                            lastAddedTime = reading.date
                            lastAddedSGV = reading.sgv
                        }
                    }

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
                LogManager.shared.log(category: .nightscout, message: "Failed to fetch bg data: \(error)", limitIdentifier: "Failed to fetch bg data")
                DispatchQueue.main.async {
                    TaskScheduler.shared.rescheduleTask(
                        id: .fetchBG,
                        to: Date().addingTimeInterval(10)
                    )
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
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value

        guard !data.isEmpty else {
            LogManager.shared.log(category: .nightscout, message: "No bg data received. Skipping processing.", limitIdentifier: "No bg data received. Skipping processing.")
            return
        }
        let latestDate = data[0].date
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        
        // Start the BG timer based on the reading
        let secondsAgo = now - latestDate
        
        DispatchQueue.main.async {
            if secondsAgo >= (20 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .fetchBG,
                    to: Date().addingTimeInterval(5 * 60)
                )
            } else if secondsAgo >= (10 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .fetchBG,
                    to: Date().addingTimeInterval(60)
                )
            } else if secondsAgo >= (7 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .fetchBG,
                    to: Date().addingTimeInterval(30)
                )
            } else if secondsAgo >= (5 * 60) {
                TaskScheduler.shared.rescheduleTask(
                    id: .fetchBG,
                    to: Date().addingTimeInterval(10)
                )
            } else {
                let delay = (300 - secondsAgo + Double(UserDefaultsRepository.bgUpdateDelay.value))
                TaskScheduler.shared.rescheduleTask(
                    id: .fetchBG,
                    to: Date().addingTimeInterval(delay)
                )

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
            TaskScheduler.shared.rescheduleTask(id: .minAgoUpdate, to: Date())

            let entries = self.bgData
            if entries.count < 2 { return } // Protect index out of bounds
            
            self.updateBGGraph()
            self.updateStats()
            
            let latestEntryIndex = entries.count - 1
            let latestBG = entries[latestEntryIndex].sgv
            let priorBG = entries[latestEntryIndex - 1].sgv
            let deltaBG = latestBG - priorBG
            let lastBGTime = entries[latestEntryIndex].date
            
            let deltaTime = (TimeInterval(Date().timeIntervalSince1970) - lastBGTime) / 60            
            self.updateServerText(with: sourceName)
            
            var snoozerBG = ""
            var snoozerDirection = ""
            var snoozerDelta = ""
            
            // Set BGText with the latest BG value
            self.BGText.text = Localizer.toDisplayUnits(String(latestBG))
            snoozerBG = Localizer.toDisplayUnits(String(latestBG))
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
                self.latestDeltaString = Localizer.toDisplayUnits(String(deltaBG))

            } else {
                self.latestDeltaString = "+" + Localizer.toDisplayUnits(String(deltaBG))
            }
            self.DeltaText.text = self.latestDeltaString
            snoozerDelta = self.latestDeltaString

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

            // Update contact
            if Storage.shared.contactEnabled.value {
                self.contactImageUpdater.updateContactImage(bgValue: bgTextStr, trend: snoozerDirection, delta: snoozerDelta, stale: deltaTime >= 12)
            }
        }
    }
}
