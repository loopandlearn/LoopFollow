// LoopFollow
// Notes.swift

import Foundation
import UIKit

extension MainViewController {
    // NS Note Response Processor
    func processNotes(entries: [[String: AnyObject]]) {
        // because it's a small array, we're going to destroy and reload every time.
        noteGraphData.removeAll()
        var lastFoundIndex = 0

        for currentEntry in entries.reversed() {
            guard let currentEntry = currentEntry as? [String: AnyObject] else { continue }

            var date: String
            if currentEntry["timestamp"] != nil {
                date = currentEntry["timestamp"] as! String
            } else if currentEntry["created_at"] != nil {
                date = currentEntry["created_at"] as! String
            } else {
                continue
            }

            if let parsedDate = NightscoutUtils.parseDate(date) {
                let dateTimeStamp = parsedDate.timeIntervalSince1970
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex

                guard let thisNote = currentEntry["notes"] as? String else { continue }

                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    let dot = DataStructs.noteStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv), note: thisNote)
                    noteGraphData.append(dot)
                }
            } else {
                print("Failed to parse date")
            }
        }

        if Storage.shared.graphOtherTreatments.value {
            updateNotes()
        }
    }
}
