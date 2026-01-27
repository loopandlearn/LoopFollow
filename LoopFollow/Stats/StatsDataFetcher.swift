// LoopFollow
// StatsDataFetcher.swift

import Foundation

class StatsDataFetcher {
    weak var mainViewController: MainViewController?

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
        let date = Calendar.current.date(byAdding: .day, value: -1 * days, to: Date())!
        parameters["count"] = "\(days * 2 * 24 * 60 / 5)"
        parameters["find[dateString][$gte]"] = utcISODateFormatter.string(from: date)
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

                    let cutoffTime = Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60)
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

        let startDate = Calendar.current.date(byAdding: .day, value: -1 * days, to: Date())!
        let endDate = Date()

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
        let cutoffTime = Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60)

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
        let cutoffTime = Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60)

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
        let cutoffTime = Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60)
        let now = Date().timeIntervalSince1970

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
        let cutoffTime = Date().timeIntervalSince1970 - (Double(days) * 24 * 60 * 60)

        var basalEntries: [[String: AnyObject]] = []
        for entry in entries {
            guard let eventType = entry["eventType"] as? String else { continue }
            if eventType == "Temp Basal" {
                basalEntries.append(entry)
            }
        }

        mainVC.statsBasalData.removeAll { $0.date < cutoffTime }

        let existingDates = Set(mainVC.statsBasalData.map { Int($0.date) })
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

            let duration = currentEntry["duration"] as? Double ?? 0.0

            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String: AnyObject]?
                let priorDateStr = priorEntry?["timestamp"] as? String ?? priorEntry?["created_at"] as? String
                if let rawPrior = priorDateStr,
                   let priorDateParsed = NightscoutUtils.parseDate(rawPrior)
                {
                    let priorDateTimeStamp = priorDateParsed.timeIntervalSince1970
                    let priorDuration = priorEntry?["duration"] as? Double ?? 0.0

                    if (dateTimeStamp - priorDateTimeStamp) > (priorDuration * 60) + 15 {
                        var scheduled = 0.0
                        var midGap = false
                        var midGapTime: TimeInterval = 0
                        var midGapValue: Double = 0

                        for b in 0 ..< mainVC.basalScheduleData.count {
                            let priorEnd = priorDateTimeStamp + (priorDuration * 60)
                            if priorEnd >= mainVC.basalScheduleData[b].date {
                                scheduled = mainVC.basalScheduleData[b].basalRate
                                if b < mainVC.basalScheduleData.count - 1 {
                                    if dateTimeStamp > mainVC.basalScheduleData[b + 1].date {
                                        midGap = true
                                        midGapTime = mainVC.basalScheduleData[b + 1].date
                                        midGapValue = mainVC.basalScheduleData[b + 1].basalRate
                                    }
                                }
                            }
                        }

                        let startDot = MainViewController.basalGraphStruct(basalRate: scheduled, date: priorDateTimeStamp + (priorDuration * 60))
                        if !existingDates.contains(Int(startDot.date)) {
                            mainVC.statsBasalData.append(startDot)
                        }

                        if midGap {
                            let endDot1 = MainViewController.basalGraphStruct(basalRate: scheduled, date: midGapTime)
                            if !existingDates.contains(Int(endDot1.date)) {
                                mainVC.statsBasalData.append(endDot1)
                            }
                            let startDot2 = MainViewController.basalGraphStruct(basalRate: midGapValue, date: midGapTime)
                            if !existingDates.contains(Int(startDot2.date)) {
                                mainVC.statsBasalData.append(startDot2)
                            }
                            let endDot2 = MainViewController.basalGraphStruct(basalRate: midGapValue, date: dateTimeStamp)
                            if !existingDates.contains(Int(endDot2.date)) {
                                mainVC.statsBasalData.append(endDot2)
                            }
                        } else {
                            let endDot = MainViewController.basalGraphStruct(basalRate: scheduled, date: dateTimeStamp)
                            if !existingDates.contains(Int(endDot.date)) {
                                mainVC.statsBasalData.append(endDot)
                            }
                        }
                    }
                }
            }

            let startDot = MainViewController.basalGraphStruct(basalRate: basalRate, date: dateTimeStamp)
            if !existingDates.contains(Int(startDot.date)) {
                mainVC.statsBasalData.append(startDot)
            }

            var lastDot = dateTimeStamp + (duration * 60)
            if i == tempArray.count - 1, duration == 0.0 {
                lastDot = dateTimeStamp + (30 * 60)
            }

            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String: AnyObject]?
                let nextDateStr = nextEntry?["timestamp"] as? String ?? nextEntry?["created_at"] as? String
                if let rawNext = nextDateStr,
                   let nextDateParsed = NightscoutUtils.parseDate(rawNext)
                {
                    let nextDateTimeStamp = nextDateParsed.timeIntervalSince1970
                    if nextDateTimeStamp < (dateTimeStamp + (duration * 60)) {
                        lastDot = nextDateTimeStamp
                    }
                }
            }

            let endDot = MainViewController.basalGraphStruct(basalRate: basalRate, date: lastDot)
            if !existingDates.contains(Int(endDot.date)) {
                mainVC.statsBasalData.append(endDot)
            }
        }

        mainVC.statsBasalData.sort { $0.date < $1.date }
    }
}
