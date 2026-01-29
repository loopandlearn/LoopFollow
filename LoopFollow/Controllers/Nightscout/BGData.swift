// LoopFollow
// BGData.swift

import Foundation
import UIKit

extension MainViewController {
    // Dex Share Web Call
    func webLoadDexShare() {
        // Dexcom Share only returns 24 hrs of data as of now
        // Requesting more just for consistency with NS
        let graphHours = 24 * Storage.shared.downloadDays.value
        let count = graphHours * 12
        dexShare?.fetchData(count) { err, result in
            if let error = err {
                LogManager.shared.log(category: .dexcom, message: "Error fetching Dexcom data: \(error.localizedDescription)", limitIdentifier: "Error fetching Dexcom data")
                self.webLoadNSBGData()
                return
            }

            guard let data = result, !data.isEmpty else {
                LogManager.shared.log(category: .dexcom, message: "Received empty data array from Dexcom", limitIdentifier: "Received empty data array from Dexcom")
                self.webLoadNSBGData()
                return
            }

            // If Dex data is old, load from NS instead
            let latestDate = data[0].date
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            if (latestDate + 330) < now, IsNightscoutEnabled() {
                LogManager.shared.log(category: .dexcom, message: "Dexcom data is old, loading from NS instead", limitIdentifier: "Dexcom data is old, loading from NS instead")
                self.webLoadNSBGData()
                return
            }

            // Dexcom only returns 24 hrs of data. If we need more, call NS.
            if graphHours > 24, IsNightscoutEnabled() {
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
            Storage.shared.lastBGChecked.value = Date()
            return
        }

        var parameters: [String: String] = [:]
        let date = Calendar.current.date(byAdding: .day, value: -1 * Storage.shared.downloadDays.value, to: Date())!
        parameters["count"] = "\(Storage.shared.downloadDays.value * 2 * 24 * 60 / 5)"
        parameters["find[date][$gte]"] = "\(Int(date.timeIntervalSince1970 * 1000))"

        // Exclude 'cal' entries
        parameters["find[type][$ne]"] = "cal"

        NightscoutUtils.executeRequest(eventType: .sgv, parameters: parameters) { (result: Result<[ShareGlucoseData], Error>) in
            switch result {
            case let .success(entriesResponse):
                var nsData = entriesResponse
                DispatchQueue.main.async {
                    // transform NS data to look like Dex data
                    for i in 0 ..< nsData.count {
                        // convert the NS timestamp to seconds instead of milliseconds
                        nsData[i].date /= 1000
                        nsData[i].date.round(FloatingPointRoundingRule.toNearestOrEven)
                    }

                    var nsData2: [ShareGlucoseData] = []
                    var lastAddedTime = Double.infinity
                    var lastAddedSGV: Int?
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
                        while itemsToRemove < nsData2.count, nsData2[itemsToRemove].date >= oldestDexDate {
                            itemsToRemove += 1
                        }
                        nsData2.removeFirst(itemsToRemove)
                        nsData2 = dexData + nsData2
                        sourceName = "Dexcom"
                    }
                    // trigger the processor for the data after downloading.
                    self.ProcessDexBGData(data: nsData2, sourceName: sourceName)
                }
            case let .failure(error):
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
                } else {
                    Storage.shared.lastBGChecked.value = Date()
                }
                return
            }
        }
    }

    /// Processes incoming BG data.
    func ProcessDexBGData(data: [ShareGlucoseData], sourceName: String) {
        let graphHours = 24 * Storage.shared.downloadDays.value

        guard !data.isEmpty else {
            LogManager.shared.log(category: .nightscout, message: "No bg data received. Skipping processing.", limitIdentifier: "No bg data received. Skipping processing.")
            Storage.shared.lastBGChecked.value = Date()
            return
        }

        let latestReading = data[0]
        let sensorTimestamp = latestReading.date
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        // secondsAgo is how old the newest reading is
        let secondsAgo = now - sensorTimestamp

        // Compute the current sensor schedule offset
        let currentOffset = CycleHelper.cycleOffset(for: sensorTimestamp, interval: 5 * 60)

        if Storage.shared.sensorScheduleOffset.value != currentOffset {
            Storage.shared.sensorScheduleOffset.value = currentOffset
            LogManager.shared.log(category: .nightscout,
                                  message: "Sensor schedule offset: \(currentOffset) seconds.",
                                  isDebug: true)
        }

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
                                      message: "Reading is close to 5 minutes old (\(secondsAgo) sec). Scheduling next fetch in 5 seconds.",
                                      isDebug: true)
            } else {
                delayToSchedule = 300 - secondsAgo + Double(Storage.shared.bgUpdateDelay.value)
                LogManager.shared.log(category: .nightscout,
                                      message: "Fresh reading. Scheduling next fetch in \(delayToSchedule) seconds.",
                                      isDebug: true)
                TaskScheduler.shared.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(3))
            }

            TaskScheduler.shared.rescheduleTask(id: .fetchBG, to: Date().addingTimeInterval(delayToSchedule))

            // Evaluate speak conditions if there is a previous value.
            if data.count > 1 {
                self.evaluateSpeakConditions(currentValue: data[0].sgv, previousValue: data[1].sgv)
            }
        }

        // Process data for graph display.
        bgData.removeAll()
        for i in 0 ..< data.count {
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

    func updateServerText(with serverText: String? = nil) {
        if Storage.shared.showDisplayName.value, let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
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
            if entries.count < 2 { // Protect index out of bounds
                Storage.shared.lastBGChecked.value = Date()
                return
            }

            self.updateBGGraph()
            self.updateStats()

            let latestEntryIndex = entries.count - 1
            let latestBG = entries[latestEntryIndex].sgv
            let priorBG = entries[latestEntryIndex - 1].sgv
            let deltaBG = latestBG - priorBG
            let lastBGTime = entries[latestEntryIndex].date

            self.updateServerText(with: sourceName)

            // Set BGText with the latest BG value
            self.setBGTextColor()

            Observable.shared.bgText.value = Localizer.toDisplayUnits(String(latestBG))
            Observable.shared.bg.value = latestBG

            // Direction handling
            if let directionBG = entries[latestEntryIndex].direction {
                Observable.shared.directionText.value = self.bgDirectionGraphic(directionBG)
            } else {
                Observable.shared.directionText.value = ""
            }

            // Delta handling
            if deltaBG < 0 {
                Observable.shared.deltaText.value = Localizer.toDisplayUnits(String(deltaBG))
            } else {
                Observable.shared.deltaText.value = "+" + Localizer.toDisplayUnits(String(deltaBG))
            }

            // Mark BG data as loaded for initial loading state
            self.markDataLoaded("bg")

            // Update contact
            if Storage.shared.contactEnabled.value {
                self.contactImageUpdater
                    .updateContactImage(
                        bgValue: Observable.shared.bgText.value,
                        trend: Observable.shared.directionText.value,
                        delta: Observable.shared.deltaText.value,
                        iob: Observable.shared.iobText.value,
                        stale: Observable.shared.bgStale.value
                    )
            }
            Storage.shared.lastBGChecked.value = Date()
        }
    }
}
