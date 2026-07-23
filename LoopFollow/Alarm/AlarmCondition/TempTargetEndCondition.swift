// LoopFollow
// TempTargetEndCondition.swift

import Foundation

/// Fires once when the active temp target ends and, if the alarm's
/// `predictiveMinutes` is set, once that many minutes before the scheduled end.
struct TempTargetEndCondition: AlarmCondition {
    static let type: AlarmType = .tempTargetEnd
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        // The ended phase must stay ahead of the early-warning phase;
        // notificationTitle(alarm:data:now:) relies on this ordering.
        if let endTS = data.latestTempTargetEnd, endTS > 0,
           now.timeIntervalSince1970 - endTS <= 15 * 60
        {
            let last = Storage.shared.lastTempTargetEndNotified.value ?? 0
            if endTS > last {
                Storage.shared.lastTempTargetEndNotified.value = endTS
                return true
            }
        }

        if let lead = alarm.predictiveMinutes, lead > 0,
           let endTS = data.activeTempTargetEnd,
           now.timeIntervalSince1970 >= endTS - Double(lead) * 60
        {
            let last = Storage.shared.lastTempTargetPreEndNotified.value ?? 0
            if endTS > last {
                Storage.shared.lastTempTargetPreEndNotified.value = endTS
                return true
            }
        }

        return false
    }

    func notificationTitle(alarm _: Alarm, data: AlarmData, now: Date) -> String? {
        guard let endTS = data.activeTempTargetEnd,
              now.timeIntervalSince1970 < endTS,
              Storage.shared.lastTempTargetPreEndNotified.value == endTS
        else { return nil }
        return "Temp Target Ending Soon"
    }
}
