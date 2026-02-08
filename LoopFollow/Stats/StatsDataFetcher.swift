// LoopFollow
// StatsDataFetcher.swift

import Foundation

class StatsDataFetcher {
    weak var mainViewController: MainViewController?
    weak var dataService: StatsDataService?

    init(mainViewController: MainViewController?) {
        self.mainViewController = mainViewController
    }

    func fetchBGData(days: Int, completion: @escaping () -> Void) {
        guard let mainVC = mainViewController, IsNightscoutEnabled() else {
            completion()
            return
        }

        var parameters: [String: String] = [:]
        let utcISODateFormatter = ISO8601DateFormatter()
        let startDate = dataService?.startDate ?? Calendar.current.date(byAdding: .day, value: -1 * days, to: Date())!
        parameters["count"] = "\(days * 2 * 24 * 60 / 5)"
        parameters["find[dateString][$gte]"] = utcISODateFormatter.string(from: startDate)
        parameters["find[type][$ne]"] = "cal"

        NightscoutUtils.executeRequest(eventType: .sgv, parameters: parameters) { (result: Result<[ShareGlucoseData], Error>) in
            switch result {
            case let .success(entriesResponse):
                var nsData = entriesResponse
                DispatchQueue.main.async {
                    // Transform NS data
                    for i in 0 ..< nsData.count {
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

                    let cutoffTime = self.dataService?.startDate.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60))
                    mainVC.statsBGData.removeAll { $0.date < cutoffTime }

                    let existingDates = Set(mainVC.statsBGData.map { Int($0.date) })
                    for reading in nsData2 {
                        if !existingDates.contains(Int(reading.date)), reading.date >= cutoffTime {
                            mainVC.statsBGData.append(reading)
                        }
                    }

                    mainVC.statsBGData.sort { $0.date < $1.date }

                    completion()
                }
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "Failed to fetch stats BG data: \(error)", limitIdentifier: "Failed to fetch stats BG data")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    func fetchTreatmentsData(days: Int, completion: @escaping () -> Void) {
        guard let mainVC = mainViewController, IsNightscoutEnabled(), Storage.shared.downloadTreatments.value else {
            completion()
            return
        }

        let utcISODateFormatter = ISO8601DateFormatter()
        utcISODateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        utcISODateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        let startDate = dataService?.startDate ?? Calendar.current.date(byAdding: .day, value: -1 * days, to: Date())!
        let endDate = dataService?.endDate ?? Date()

        let startTimeString = utcISODateFormatter.string(from: startDate)
        let currentTimeString = utcISODateFormatter.string(from: endDate)

        let estimatedCount = max(days * 100, 5000)
        let parameters: [String: String] = [
            "find[created_at][$gte]": startTimeString,
            "find[created_at][$lte]": currentTimeString,
            "count": "\(estimatedCount)",
        ]

        NightscoutUtils.executeDynamicRequest(eventType: .treatments, parameters: parameters) { (result: Result<Any, Error>) in
            switch result {
            case let .success(data):
                if let entries = data as? [[String: AnyObject]] {
                    DispatchQueue.main.async {
                        self.fetchAndMergeBolusData(entries: entries, days: days, mainVC: mainVC)
                        self.fetchAndMergeSMBData(entries: entries, days: days, mainVC: mainVC)
                        self.fetchAndMergeCarbData(entries: entries, days: days, mainVC: mainVC)
                        self.fetchAndMergeBasalData(entries: entries, days: days, mainVC: mainVC)
                        completion()
                    }
                } else {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            case let .failure(error):
                LogManager.shared.log(category: .nightscout, message: "Failed to fetch stats treatments data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    private func fetchAndMergeBolusData(entries: [[String: AnyObject]], days: Int, mainVC: MainViewController) {
        let cutoffTime = dataService?.startDate.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60))

        var bolusEntries: [[String: AnyObject]] = []
        for entry in entries {
            guard let eventType = entry["eventType"] as? String else { continue }
            if eventType == "Correction Bolus" || eventType == "Bolus" || eventType == "External Insulin" {
                if let automatic = entry["automatic"] as? Bool, automatic {
                    continue
                }
                bolusEntries.append(entry)
            } else if eventType == "Meal Bolus" {
                bolusEntries.append(entry)
            }
        }

        mainVC.statsBolusData.removeAll { $0.date < cutoffTime }

        let existingDates = Set(mainVC.statsBolusData.map { Int($0.date) })
        var lastFoundIndex = 0

        for currentEntry in bolusEntries.reversed() {
            var bolusDate: String
            if currentEntry["timestamp"] != nil {
                bolusDate = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                bolusDate = currentEntry["created_at"] as! String
            } else {
                continue
            }

            guard let parsedDate = NightscoutUtils.parseDate(bolusDate),
                  let bolus = currentEntry["insulin"] as? Double else { continue }

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            if dateTimeStamp < cutoffTime { continue }

            // Avoid duplicates (use Int to handle floating point precision)
            if existingDates.contains(Int(dateTimeStamp)) { continue }

            let sgv = mainVC.findNearestBGbyTime(needle: dateTimeStamp, haystack: mainVC.statsBGData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            let dot = MainViewController.bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
            mainVC.statsBolusData.append(dot)
        }

        mainVC.statsBolusData.sort { $0.date < $1.date }
    }

    private func fetchAndMergeSMBData(entries: [[String: AnyObject]], days: Int, mainVC: MainViewController) {
        let cutoffTime = dataService?.startDate.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60))

        var smbEntries: [[String: AnyObject]] = []
        for entry in entries {
            guard let eventType = entry["eventType"] as? String else { continue }
            if eventType == "SMB" {
                smbEntries.append(entry)
            } else if eventType == "Correction Bolus" || eventType == "Bolus" || eventType == "External Insulin" {
                if let automatic = entry["automatic"] as? Bool, automatic {
                    smbEntries.append(entry)
                }
            }
        }

        mainVC.statsSMBData.removeAll { $0.date < cutoffTime }

        let existingDates = Set(mainVC.statsSMBData.map { Int($0.date) })
        var lastFoundIndex = 0

        for currentEntry in smbEntries.reversed() {
            var bolusDate: String
            if currentEntry["timestamp"] != nil {
                bolusDate = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                bolusDate = currentEntry["created_at"] as! String
            } else {
                continue
            }

            guard let parsedDate = NightscoutUtils.parseDate(bolusDate),
                  let bolus = currentEntry["insulin"] as? Double else { continue }

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            if dateTimeStamp < cutoffTime { continue }

            if existingDates.contains(Int(dateTimeStamp)) { continue }

            let sgv = mainVC.findNearestBGbyTime(needle: dateTimeStamp, haystack: mainVC.statsBGData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            let dot = MainViewController.bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
            mainVC.statsSMBData.append(dot)
        }

        mainVC.statsSMBData.sort { $0.date < $1.date }
    }

    private func fetchAndMergeCarbData(entries: [[String: AnyObject]], days: Int, mainVC: MainViewController) {
        let cutoffTime = dataService?.startDate.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60))
        let now = dataService?.endDate.timeIntervalSince1970 ?? Date().timeIntervalSince1970

        var carbEntries: [[String: AnyObject]] = []
        for entry in entries {
            guard let eventType = entry["eventType"] as? String else { continue }
            if eventType == "Carb Correction" || eventType == "Meal Bolus" {
                carbEntries.append(entry)
            }
        }

        mainVC.statsCarbData.removeAll { $0.date < cutoffTime || $0.date > now }

        let existingDates = Set(mainVC.statsCarbData.map { Int($0.date) })
        var lastFoundIndex = 0
        var lastFoundBolus = 0

        for currentEntry in carbEntries.reversed() {
            var carbDate: String
            if currentEntry["timestamp"] != nil {
                carbDate = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                carbDate = currentEntry["created_at"] as! String
            } else {
                continue
            }

            let absorptionTime = currentEntry["absorptionTime"] as? Int ?? 0

            guard let parsedDate = NightscoutUtils.parseDate(carbDate),
                  let carbs = currentEntry["carbs"] as? Double else { continue }

            let dateTimeStamp = parsedDate.timeIntervalSince1970

            if dateTimeStamp < cutoffTime || dateTimeStamp > now { continue }

            if existingDates.contains(Int(dateTimeStamp)) { continue }

            let sgv = mainVC.findNearestBGbyTime(needle: dateTimeStamp, haystack: mainVC.statsBGData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            var offset = -50
            if sgv.sgv < Double(mainVC.calculateMaxBgGraphValue() - 100) {
                let bolusTime = mainVC.findNearestBolusbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: mainVC.statsBolusData, startingIndex: lastFoundBolus)
                lastFoundBolus = bolusTime.foundIndex
                offset = bolusTime.offset ? 70 : 20
            }

            let dot = MainViewController.carbGraphStruct(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv + Double(offset)), absorptionTime: absorptionTime)
            mainVC.statsCarbData.append(dot)
        }

        mainVC.statsCarbData.sort { $0.date < $1.date }
    }

    private func fetchAndMergeBasalData(entries: [[String: AnyObject]], days: Int, mainVC: MainViewController) {
        let cutoffTime = dataService?.startDate.timeIntervalSince1970 ?? (Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60))
        let now = dataService?.endDate.timeIntervalSince1970 ?? Date().timeIntervalSince1970

        var basalEntries: [[String: AnyObject]] = []
        for entry in entries {
            guard let eventType = entry["eventType"] as? String else { continue }
            if eventType == "Temp Basal" {
                basalEntries.append(entry)
            }
        }

        mainVC.statsBasalData.removeAll { $0.date < cutoffTime }

        // Clear and rebuild temp basal entries for stats calculation
        dataService?.tempBasalEntries.removeAll { $0.startTime < cutoffTime }
        var existingTempBasalTimes = Set(dataService?.tempBasalEntries.map { Int($0.startTime) } ?? [])

        var existingDates = Set(mainVC.statsBasalData.map { Int($0.date) })
        var tempArray = basalEntries
        tempArray.reverse()

        for i in 0 ..< tempArray.count {
            guard let currentEntry = tempArray[i] as [String: AnyObject]? else { continue }

            let dateString = currentEntry["timestamp"] as? String ?? currentEntry["created_at"] as? String
            guard let rawDateStr = dateString,
                  let dateParsed = NightscoutUtils.parseDate(rawDateStr)
            else {
                continue
            }

            let dateTimeStamp = dateParsed.timeIntervalSince1970
            if dateTimeStamp < cutoffTime { continue }

            guard let basalRate = currentEntry["absolute"] as? Double else {
                continue
            }

            var duration = currentEntry["duration"] as? Double ?? 0.0

            // Store raw temp basal entry for stats calculation
            // Adjust duration if it overlaps with next temp basal
            var effectiveDuration = duration
            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String: AnyObject]?
                let nextDateStr = nextEntry?["timestamp"] as? String ?? nextEntry?["created_at"] as? String
                if let rawNext = nextDateStr,
                   let nextDateParsed = NightscoutUtils.parseDate(rawNext)
                {
                    let nextDateTimeStamp = nextDateParsed.timeIntervalSince1970
                    let tempBasalEnd = dateTimeStamp + (duration * 60)
                    if nextDateTimeStamp < tempBasalEnd {
                        // Adjust duration to end when next temp basal starts
                        effectiveDuration = (nextDateTimeStamp - dateTimeStamp) / 60.0
                    }
                }
            }

            if !existingTempBasalTimes.contains(Int(dateTimeStamp)) {
                let tempBasalEntry = StatsDataService.TempBasalEntry(
                    rate: basalRate,
                    startTime: dateTimeStamp,
                    durationMinutes: effectiveDuration > 0 ? effectiveDuration : 30.0
                )
                dataService?.tempBasalEntries.append(tempBasalEntry)
                existingTempBasalTimes.insert(Int(dateTimeStamp))
            }

            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String: AnyObject]?
                let priorDateStr = priorEntry?["timestamp"] as? String ?? priorEntry?["created_at"] as? String
                if let rawPrior = priorDateStr,
                   let priorDateParsed = NightscoutUtils.parseDate(rawPrior)
                {
                    let priorDateTimeStamp = priorDateParsed.timeIntervalSince1970
                    let priorDuration = priorEntry?["duration"] as? Double ?? 0.0
                    let priorEndTime = priorDateTimeStamp + (priorDuration * 60)

                    if (dateTimeStamp - priorEndTime) > 15 {
                        let gapEntries = createScheduledBasalEntriesForGap(
                            from: priorEndTime,
                            to: dateTimeStamp,
                            profile: mainVC.basalProfile,
                            existingDates: existingDates
                        )
                        for entry in gapEntries {
                            if !existingDates.contains(Int(entry.date)) {
                                mainVC.statsBasalData.append(entry)
                                existingDates.insert(Int(entry.date))
                            }
                        }
                    }
                }
            }

            let startDot = MainViewController.basalGraphStruct(basalRate: basalRate, date: dateTimeStamp)
            if !existingDates.contains(Int(startDot.date)) {
                mainVC.statsBasalData.append(startDot)
                existingDates.insert(Int(startDot.date))
            }

            var endTime = dateTimeStamp + (duration * 60)
            if i == tempArray.count - 1, duration == 0.0 {
                endTime = dateTimeStamp + (30 * 60)
            }

            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String: AnyObject]?
                let nextDateStr = nextEntry?["timestamp"] as? String ?? nextEntry?["created_at"] as? String
                if let rawNext = nextDateStr,
                   let nextDateParsed = NightscoutUtils.parseDate(rawNext)
                {
                    let nextDateTimeStamp = nextDateParsed.timeIntervalSince1970
                    if nextDateTimeStamp < endTime {
                        endTime = nextDateTimeStamp
                    }
                }
            }

            let endDot = MainViewController.basalGraphStruct(basalRate: basalRate, date: endTime)
            if !existingDates.contains(Int(endDot.date)) {
                mainVC.statsBasalData.append(endDot)
                existingDates.insert(Int(endDot.date))
            }
        }

        if !tempArray.isEmpty {
            let firstEntry = tempArray.first as [String: AnyObject]?
            let firstDateStr = firstEntry?["timestamp"] as? String ?? firstEntry?["created_at"] as? String
            if let rawFirst = firstDateStr,
               let firstDateParsed = NightscoutUtils.parseDate(rawFirst)
            {
                let firstTempBasalStart = firstDateParsed.timeIntervalSince1970
                if firstTempBasalStart > cutoffTime {
                    let gapEntries = createScheduledBasalEntriesForGap(
                        from: cutoffTime,
                        to: firstTempBasalStart,
                        profile: mainVC.basalProfile,
                        existingDates: existingDates
                    )
                    for entry in gapEntries {
                        if !existingDates.contains(Int(entry.date)) {
                            mainVC.statsBasalData.append(entry)
                            existingDates.insert(Int(entry.date))
                        }
                    }
                }
            }
        } else if !mainVC.basalProfile.isEmpty {
            let gapEntries = createScheduledBasalEntriesForGap(
                from: cutoffTime,
                to: now,
                profile: mainVC.basalProfile,
                existingDates: existingDates
            )
            for entry in gapEntries {
                if !existingDates.contains(Int(entry.date)) {
                    mainVC.statsBasalData.append(entry)
                    existingDates.insert(Int(entry.date))
                }
            }
        }

        if !tempArray.isEmpty {
            let lastEntry = tempArray.last as [String: AnyObject]?
            let lastDateStr = lastEntry?["timestamp"] as? String ?? lastEntry?["created_at"] as? String
            let lastDuration = lastEntry?["duration"] as? Double ?? 30.0
            if let rawLast = lastDateStr,
               let lastDateParsed = NightscoutUtils.parseDate(rawLast)
            {
                let lastTempBasalEnd = lastDateParsed.timeIntervalSince1970 + (lastDuration * 60)
                if lastTempBasalEnd < now {
                    let gapEntries = createScheduledBasalEntriesForGap(
                        from: lastTempBasalEnd,
                        to: now,
                        profile: mainVC.basalProfile,
                        existingDates: existingDates
                    )
                    for entry in gapEntries {
                        if !existingDates.contains(Int(entry.date)) {
                            mainVC.statsBasalData.append(entry)
                            existingDates.insert(Int(entry.date))
                        }
                    }
                }
            }
        }

        mainVC.statsBasalData.sort { $0.date < $1.date }
    }

    private func createScheduledBasalEntriesForGap(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        profile: [MainViewController.basalProfileStruct],
        existingDates: Set<Int>
    ) -> [MainViewController.basalGraphStruct] {
        guard !profile.isEmpty, endTime > startTime else { return [] }

        var entries: [MainViewController.basalGraphStruct] = []
        let sortedProfile = profile.sorted { $0.timeAsSeconds < $1.timeAsSeconds }
        let calendar = Calendar.current

        var currentTime = startTime
        while currentTime < endTime {
            let currentDate = Date(timeIntervalSince1970: currentTime)
            let dayStart = calendar.startOfDay(for: currentDate).timeIntervalSince1970
            let nextDayStart = dayStart + 24 * 60 * 60

            for i in 0 ..< sortedProfile.count {
                let segmentRate = sortedProfile[i].value
                let segmentStartInDay = dayStart + sortedProfile[i].timeAsSeconds

                let segmentEndInDay: TimeInterval
                if i < sortedProfile.count - 1 {
                    segmentEndInDay = dayStart + sortedProfile[i + 1].timeAsSeconds
                } else {
                    segmentEndInDay = nextDayStart
                }

                let overlapStart = max(currentTime, segmentStartInDay)
                let overlapEnd = min(endTime, segmentEndInDay)

                if overlapEnd > overlapStart, !existingDates.contains(Int(overlapStart)) {
                    let startEntry = MainViewController.basalGraphStruct(basalRate: segmentRate, date: overlapStart)
                    entries.append(startEntry)

                    if overlapEnd < endTime, !existingDates.contains(Int(overlapEnd)) {
                        let endEntry = MainViewController.basalGraphStruct(basalRate: segmentRate, date: overlapEnd)
                        entries.append(endEntry)
                    }
                }
            }

            currentTime = nextDayStart
        }

        return entries
    }
}
