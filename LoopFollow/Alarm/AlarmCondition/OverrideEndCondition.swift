// LoopFollow
// OverrideEndCondition.swift

import Foundation

/// Fires once when the active override ends and, if the alarm's
/// `predictiveMinutes` is set, once that many minutes before the scheduled end.
struct OverrideEndCondition: AlarmCondition {
    static let type: AlarmType = .overrideEnd
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        // The ended phase must stay ahead of the early-warning phase;
        // notificationTitle(alarm:data:now:) relies on this ordering.
        if let endTS = data.latestOverrideEnd, endTS > 0,
           now.timeIntervalSince1970 - endTS <= 15 * 60
        {
            let last = Storage.shared.lastOverrideEndNotified.value ?? 0
            if endTS > last {
                Storage.shared.lastOverrideEndNotified.value = endTS
                return true
            }
        }

        if let lead = alarm.predictiveMinutes, lead > 0,
           let endTS = data.activeOverrideEnd,
           now.timeIntervalSince1970 >= endTS - Double(lead) * 60
        {
            let last = Storage.shared.lastOverridePreEndNotified.value ?? 0
            if endTS > last {
                Storage.shared.lastOverridePreEndNotified.value = endTS
                return true
            }
        }

        return false
    }

    func notificationTitle(alarm _: Alarm, data: AlarmData, now: Date) -> String? {
        guard let endTS = data.activeOverrideEnd,
              now.timeIntervalSince1970 < endTS,
              Storage.shared.lastOverridePreEndNotified.value == endTS
        else { return nil }
        return "Override Ending Soon"
    }
}
