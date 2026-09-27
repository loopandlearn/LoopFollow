// LoopFollow
// Notes.swift

import Foundation

extension MainViewController {
    // NS Note Response Processor
    func processNotes(entries: [[String: AnyObject]]) {
        // because it's a small array, we're going to destroy and reload every time.
        noteGraphData.removeAll()
        cgmSensorStates.removeAll()
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

                guard let thisNote = currentEntry["notes"] as? String,
                      dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60))
                else { continue }

                if let state = CGMSensorState(note: thisNote, date: parsedDate) {
                    cgmSensorStates.append(state)
                    continue
                }

                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex

                let dot = DataStructs.noteStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv), note: thisNote)
                noteGraphData.append(dot)
            } else {
                print("Failed to parse date")
            }
        }

        if Storage.shared.graphOtherTreatments.value {
            updateNotes()
        }
        updateCGMSensorState()
    }

    /// Publishes the CGM state reported after the newest reading, if any.
    func updateCGMSensorState() {
        let latestBGDate = bgData.last.map { Date(timeIntervalSince1970: $0.date) }
        let active = CGMSensorState.active(in: cgmSensorStates, latestBGDate: latestBGDate)
        guard active != Observable.shared.cgmSensorState.value else { return }

        Observable.shared.cgmSensorState.value = active
        if let active {
            LogManager.shared.log(category: .nightscout, message: "CGM sensor state: \(active.name) at \(active.date)")
        } else {
            LogManager.shared.log(category: .nightscout, message: "CGM sensor state cleared")
        }
        #if !targetEnvironment(macCatalyst)
            LiveActivityManager.shared.refreshFromCurrentState(reason: "cgmSensorState")
        #endif
    }
}
