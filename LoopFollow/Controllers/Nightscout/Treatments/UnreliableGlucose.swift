// LoopFollow
// UnreliableGlucose.swift

import Foundation

extension MainViewController {
    /// Trio ("Show Unreliable G7 Readings") uploads each Dexcom G7 reading the sensor marks unreliable as an
    /// "Unreliable Glucose" treatment, never as an entry. Drawn as hollow orange dots, and the newest shown in orange
    /// with a warning sign under the BG while it is newer than the last reliable reading. Never alarmed on, counted in
    /// the statistics or used as BG.
    func processNSUnreliableGlucose(entries: [[String: AnyObject]]) {
        var readings: [ShareGlucoseData] = []
        for entry in entries {
            guard let dateString = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                  let date = NightscoutUtils.parseDate(dateString)?.timeIntervalSince1970
            else { continue }
            let value = (entry["glucose"] as? NSNumber)?.doubleValue ?? Double(entry["glucose"] as? String ?? "")
            guard var mgdl = value, mgdl > 0 else { continue }
            if let units = entry["units"] as? String, units.lowercased().hasPrefix("mmol") { mgdl *= 18.0182 }
            readings.append(ShareGlucoseData(sgv: Int(mgdl.rounded()), date: date, direction: nil))
        }
        readings.sort { $0.date < $1.date }
        guard readings.map(\.date) != unreliableGraphData.map(\.date) else { return }
        unreliableGraphData = readings
        Observable.shared.unreliableBG.value = readings.last?.sgv
        Observable.shared.unreliableBGDate.value = readings.last?.date
        chartModel.rebuild()
    }
}
