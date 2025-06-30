// LoopFollow
// Profile.swift
// Created by Jonas Björkert.

import Foundation

extension MainViewController {
    // NS Profile Web Call
    func webLoadNSProfile() {
        NightscoutUtils.executeRequest(eventType: .profile, parameters: [:]) { (result: Result<NSProfile, Error>) in
            switch result {
            case let .success(profileData):
                self.updateProfile(profileData: profileData)
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "webLoadNSProfile, error fetching profile data: \(error.localizedDescription)")
            }
        }
    }

    // NS Profile Response Processor
    func updateProfile(profileData: NSProfile) {
        guard let store = profileData.store["default"] ?? profileData.store["Default"] else {
            return
        }
        profileManager.loadProfile(from: profileData)
        infoManager.updateInfoData(type: .profile, value: profileData.defaultProfile)

        basalProfile.removeAll()
        for basalEntry in store.basal {
            let entry = basalProfileStruct(value: basalEntry.value, time: basalEntry.time, timeAsSeconds: basalEntry.timeAsSeconds)
            basalProfile.append(entry)
        }

        // Don't process the basal or draw the graph until after the BG has been fully processeed and drawn
        if firstGraphLoad { return }

        var basalSegments: [DataStructs.basalProfileSegment] = []

        let graphHours = 24 * Storage.shared.downloadDays.value
        // Build scheduled basal segments from right to left by
        // moving pointers to the current midnight and current basal
        var midnight = dateTimeUtils.getTimeIntervalMidnightToday()
        var basalProfileIndex = basalProfile.count - 1
        var start = midnight + basalProfile[basalProfileIndex].timeAsSeconds
        var end = dateTimeUtils.getNowTimeIntervalUTC()
        // Move back until we're in the graph range
        while start > end {
            basalProfileIndex -= 1
            start = midnight + basalProfile[basalProfileIndex].timeAsSeconds
        }
        // Add records while they're still within the graph
        let graphStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
        while end >= graphStart {
            let entry = DataStructs.basalProfileSegment(
                basalRate: basalProfile[basalProfileIndex].value, startDate: start, endDate: end
            )
            basalSegments.append(entry)

            basalProfileIndex -= 1
            if basalProfileIndex < 0 {
                basalProfileIndex = basalProfile.count - 1
                midnight = midnight.advanced(by: -24 * 60 * 60)
            }
            end = start - 1
            start = midnight + basalProfile[basalProfileIndex].timeAsSeconds
        }
        // reverse the result to get chronological order
        basalSegments.reverse()

        var firstPass = true
        // Runs the scheduled basal to the end of the prediction line
        var predictionEndTime = dateTimeUtils.getNowTimeIntervalUTC() + (3600 * Storage.shared.predictionToLoad.value)
        basalScheduleData.removeAll()

        for i in 0 ..< basalSegments.count {
            let timeStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)

            // This processed everything after the first one.
            if firstPass == false,
               basalSegments[i].startDate <= predictionEndTime
            {
                let startDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: basalSegments[i].startDate)
                basalScheduleData.append(startDot)
                var endDate = basalSegments[i].endDate

                // if it's the last one needed, set it to end at the prediction end time
                if endDate > predictionEndTime || i == basalSegments.count - 1 {
                    endDate = Double(predictionEndTime)
                }

                let endDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: endDate)
                basalScheduleData.append(endDot)
            }

            // we need to manually set the first one
            // Check that this is the first one and there are no existing entries
            if firstPass == true {
                // check that the timestamp is > the current entry and < the next entry
                if timeStart >= basalSegments[i].startDate, timeStart < basalSegments[i].endDate {
                    // Set the start time to match the BG start
                    let startDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: Double(timeStart + (60 * 5)))
                    basalScheduleData.append(startDot)

                    // set the enddot where the next one will start
                    var endDate = basalSegments[i].endDate
                    let endDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: endDate)
                    basalScheduleData.append(endDot)
                    firstPass = false
                }
            }
        }

        if Storage.shared.graphBasal.value {
            updateBasalScheduledGraph()
        }
    }
}
