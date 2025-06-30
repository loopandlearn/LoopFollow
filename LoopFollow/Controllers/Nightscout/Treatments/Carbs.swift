// LoopFollow
// Carbs.swift
// Created by Jonas Björkert.

import Foundation

extension MainViewController {
    // NS Carb Bolus Response Processor
    func processNSCarbs(entries: [[String: AnyObject]]) {
        // Because it's a small array, we're going to destroy and reload every time.
        carbData.removeAll()
        var lastFoundIndex = 0
        var lastFoundBolus = 0

        for currentEntry in entries.reversed() {
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
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            var offset = -50
            if sgv.sgv < Double(calculateMaxBgGraphValue() - 100) {
                let bolusTime = findNearestBolusbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: bolusData, startingIndex: lastFoundBolus)
                lastFoundBolus = bolusTime.foundIndex

                offset = bolusTime.offset ? 70 : 20
            }

            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (3600 * Storage.shared.predictionToLoad.value)) {
                // Make the dot
                let dot = carbGraphStruct(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv + Double(offset)), absorptionTime: absorptionTime)
                carbData.append(dot)
            }
        }

        if Storage.shared.graphCarbs.value {
            updateCarbGraph()
        }
    }

    func updateTodaysCarbsFromEntries(entries: [[String: AnyObject]]) {
        var totalCarbs = 0.0

        let calendar = Calendar.current

        for entry in entries {
            var carbDate = ""

            if let timestamp = entry["timestamp"] as? String {
                carbDate = timestamp
            } else if let createdAt = entry["created_at"] as? String {
                carbDate = createdAt
            } else {
                print("Skipping entry with no timestamp or created_at")
                continue
            }

            guard let date = NightscoutUtils.parseDate(carbDate) else {
                continue
            }

            if calendar.isDateInToday(date) {
                if let carbs = entry["carbs"] as? Double {
                    totalCarbs += carbs
                } else {
                    print("Carbs not found for entry")
                }
            }
        }

        let resultString = String(format: "%.0f", totalCarbs)
        infoManager.updateInfoData(type: .carbsToday, value: resultString)
    }
}
