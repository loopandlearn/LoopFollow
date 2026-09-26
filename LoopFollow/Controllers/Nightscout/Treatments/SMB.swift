// LoopFollow
// SMB.swift

import Foundation

extension MainViewController {
    // NS SMB Processor
    func processNSSmb(entries: [[String: AnyObject]]) {
        smbData.removeAll()
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
                smbData.append(dot)
            }
        }

        if Storage.shared.graphBolus.value {
            updateSmbGraph()
        }
    }
}
