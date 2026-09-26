// LoopFollow
// Bolus.swift

import Foundation

extension MainViewController {
    // NS Meal Bolus Response Processor
    func processNSBolus(entries: [[String: AnyObject]]) {
        // because it's a small array, we're going to destroy and reload every time.
        bolusData.removeAll()
        var lastFoundIndex = 0

        for currentEntry in entries.reversed() {
            guard let parsedDate = NightscoutUtils.treatmentDate(from: currentEntry),
                  let bolus = currentEntry["insulin"] as? Double else { continue }

            let dateTimeStamp = parsedDate.timeIntervalSince1970
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex

            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
                bolusData.append(dot)
            }
        }

        if Storage.shared.graphBolus.value {
            updateBolusGraph()
        }
    }
}
