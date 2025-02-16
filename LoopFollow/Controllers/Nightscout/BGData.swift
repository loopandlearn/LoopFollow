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
                LogManager.shared.log(category: .dexcom, message: "Error fetching Dexcom data: \(error.localizedDescription)")
                self.webLoadNSBGData()
                return
            }
            
            guard let data = result else {
                LogManager.shared.log(category: .dexcom, message: "Received nil data from Dexcom")
                self.webLoadNSBGData()
                return
            }
            
            // If Dex data is old, load from NS instead
            let latestDate = data[0].date
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            if (latestDate + 330) < now && IsNightscoutEnabled() {
                LogManager.shared.log(category: .dexcom, message: "Dexcom data is old, loading from NS instead")
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
                LogManager.shared.log(category: .nightscout, message: "Failed to fetch data: \(error)")
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
    
    /// Processes incoming BG data.
    func ProcessDexBGData(data: [ShareGlucoseData], sourceName: String) {
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value

        guard !data.isEmpty else {
            LogManager.shared.log(category: .nightscout, message: "No bg data received. Skipping processing.")
            return
        }

        let latestReading = data[0]
        let sensorTimestamp = latestReading.date
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        // secondsAgo is how old the newest reading is
        let secondsAgo = now - sensorTimestamp

        LogManager.shared.log(category: .nightscout,
                              message: "Processing BG Data. Latest sensor reading: \(sensorTimestamp), now: \(now), secondsAgo: \(secondsAgo).",
                              isDebug: true)

        // Check if we have a new reading (i.e. sensor timestamp is greater than what we last saw).
        if let lastTS = lastProcessedTimestamp {
            if sensorTimestamp > lastTS {
                let observedDelay = now - sensorTimestamp
                addObservedDelay(observedDelay: observedDelay)
                lastProcessedTimestamp = sensorTimestamp
                LogManager.shared.log(category: .nightscout,
                                      message: "New reading detected. Sensor time: \(sensorTimestamp) updated (was \(lastTS)). Observed delay: \(observedDelay) seconds.",
                                      isDebug: true)
            } else {
                LogManager.shared.log(category: .nightscout,
                                      message: "No new reading. Last processed sensor timestamp remains \(lastTS).",
                                      isDebug: true)
            }
        } else {
            lastProcessedTimestamp = sensorTimestamp
            LogManager.shared.log(category: .nightscout,
                                  message: "First reading processed. Sensor time: \(sensorTimestamp)",
                                  isDebug: true)
        }

        // Compute a typical delay from our historical data.
        let typicalDelay = computeOptimalDelay()

        // Determine the next polling delay.
        var delayToSchedule: Double = 0

        DispatchQueue.main.async {
            // Fallback scheduling for older readings.
            if secondsAgo >= (20 * 60) {
                delayToSchedule = 5 * 60
                LogManager.shared.log(category: .nightscout,
                                      message: "Reading is very old (\(secondsAgo) sec). Scheduling next fetch in 5 minutes.",
                                      isDebug: true)
            } else if secondsAgo >= (10 * 60) {
                delayToSchedule = 60
                LogManager.shared.log(category: .nightscout,
                                      message: "Reading is moderately old (\(secondsAgo) sec). Scheduling next fetch in 60 seconds.",
                                      isDebug: true)
            } else if secondsAgo >= (7 * 60) {
                delayToSchedule = 30
                LogManager.shared.log(category: .nightscout,
                                      message: "Reading is a bit old (\(secondsAgo) sec). Scheduling next fetch in 30 seconds.",
                                      isDebug: true)
            } else if secondsAgo >= (5 * 60) {
                delayToSchedule = 5
                LogManager.shared.log(category: .nightscout,
                                      message: "Reading is clost to 5 minutes old (\(secondsAgo) sec). Scheduling next fetch in 10 seconds.",
                                      isDebug: true)
            } else {
                // For fresh readings, predict when the next reading should appear.
                // The sensor is scheduled to take a measurement every 300 seconds.
                // Our base delay is: time remaining until 5 minutes from sensor timestamp + typical delay.
                let baseDelay = 300 - secondsAgo + typicalDelay
                delayToSchedule = baseDelay
                LogManager.shared.log(category: .nightscout,
                                      message: "Fresh reading. Base delay computed as: 300 - \(secondsAgo) + \(typicalDelay) = \(baseDelay) seconds.",
                                      isDebug: true)

                // Exploration: occasionally try polling earlier than expected.
                let explorationRoll = Double.random(in: 0..<1)
                // Chance (0.0–1.0) to try an earlier poll than predicted.
                let explorationProbability: Double = 0.2

                if explorationRoll < explorationProbability {
                    // The absolute minimum delay we allow.
                    let minDelay: Double = 3.0

                    // How many seconds to subtract when doing an exploratory poll.
                    let explorationOffset: Double = 1

                    let exploredDelay = max(minDelay, baseDelay - explorationOffset)
                    LogManager.shared.log(category: .nightscout,
                                          message: "Exploration triggered. Adjusting delay from \(baseDelay) to \(exploredDelay) seconds.",
                                          isDebug: true)
                    delayToSchedule = exploredDelay
                }
            }

            // Log and schedule the next fetch.
            LogManager.shared.log(category: .nightscout,
                                  message: "Scheduling next BG fetch in \(delayToSchedule) seconds (at \(Date().addingTimeInterval(delayToSchedule))).",
                                  isDebug: true)
            TaskScheduler.shared.rescheduleTask(id: .fetchBG, to: Date().addingTimeInterval(delayToSchedule))

            // Evaluate speak conditions if there is a previous value.
            if data.count > 1 {
                self.evaluateSpeakConditions(currentValue: data[0].sgv, previousValue: data[1].sgv)
            }
        }

        // Process data for graph display.
        bgData.removeAll()
        for i in 0..<data.count {
            let readingTimestamp = data[data.count - 1 - i].date
            if readingTimestamp >= dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                let sgvValue = data[data.count - 1 - i].sgv

                // Skip outlier values (e.g. first reading of a new sensor might be abnormally high).
                if sgvValue > 600 {
                    LogManager.shared.log(category: .nightscout,
                                          message: "Skipping reading with sgv \(sgvValue) as it exceeds threshold.",
                                          isDebug: true)
                    continue
                }

                let reading = ShareGlucoseData(sgv: sgvValue, date: readingTimestamp, direction: data[data.count - 1 - i].direction)
                bgData.append(reading)
            }
        }

        LogManager.shared.log(category: .nightscout,
                              message: "Graph data updated with \(bgData.count) entries.",
                              isDebug: true)
        viewUpdateNSBG(sourceName: sourceName)
    }

    private func computeOptimalDelay() -> Double {
        if Storage.shared.bgDelayDynamicEnabled.value {

            guard let optimal = observedDelays.min() else {
                LogManager.shared.log(category: .nightscout,
                                      message: "No previous observed delays, starting with 10 seconds.",
                                      isDebug: true)
                return 10
            }

            LogManager.shared.log(category: .nightscout,
                                  message: "Computed optimal delay from observations \(observedDelays) is \(optimal) seconds.",
                                  isDebug: true)
            return optimal
        } else {
            LogManager.shared.log(category: .nightscout,
                                  message: "Dynamic bg delay is disabled, using user set value of \(UserDefaultsRepository.bgUpdateDelay.value) seconds.",
                                  isDebug: true)
            return Double(UserDefaultsRepository.bgUpdateDelay.value)
        }
    }

    private func addObservedDelay(observedDelay : Double) {
        guard observedDelay > 3, observedDelay < 45 else {
            LogManager.shared.log(category: .nightscout,
                                  message: "Observed delay of \(observedDelay) seconds is out of range, ignored.",
                                  isDebug: true)
            return
        }

        observedDelays.append(observedDelay)
        
        // Keep delays for the last hour
        if observedDelays.count > 12 {
            observedDelays.removeFirst()
        }
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
            if ObservableUserDefaults.shared.contactEnabled.value {
                var extra: String = ""

                if ObservableUserDefaults.shared.contactTrend.value {
                    extra = snoozerDirection
                } else if ObservableUserDefaults.shared.contactDelta.value {
                    extra = snoozerDelta
                }

                self.contactImageUpdater.updateContactImage(bgValue: bgTextStr, extra: extra, stale: deltaTime >= 12)
            }
        }
    }
}
