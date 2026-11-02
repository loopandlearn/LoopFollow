// LoopFollow
// EndAlarmPhases.swift

import Foundation

/// What an end alarm reports: the event has ended, or its scheduled end is
/// within the alarm's early-warning lead time.
enum EndAlarmPhase {
    case ended
    case endingSoon
}

/// Two-phase evaluation shared by the temp target and override end alarms.
/// Each phase fires at most once per event; the markers hold the end
/// timestamp of the event that last fired that phase.
struct EndAlarmPhases {
    /// Ends older than this are not reported.
    static let endedGrace: TimeInterval = 15 * 60

    let latestStart: TimeInterval?
    let latestEnd: TimeInterval?
    let activeEnd: TimeInterval?
    let leadMinutes: Int?
    let endedMarker: StorageValue<TimeInterval?>
    let warnedMarker: StorageValue<TimeInterval?>

    /// The ended phase takes precedence when both are due in the same tick.
    func fire(now: Date) -> EndAlarmPhase? {
        let nowTS = now.timeIntervalSince1970

        if let endTS = latestEnd, endTS > 0,
           nowTS - endTS <= Self.endedGrace,
           endTS > (endedMarker.value ?? 0)
        {
            endedMarker.value = endTS
            return .ended
        }

        guard let lead = leadMinutes, lead > 0, let endTS = activeEnd else { return nil }
        let warningOpensAt = endTS - Double(lead) * 60
        // An event shorter than the lead time is covered by its start alarm.
        if let startTS = latestStart, warningOpensAt <= startTS { return nil }
        guard nowTS >= warningOpensAt, warnedMarker.value != endTS else { return nil }
        warnedMarker.value = endTS
        return .endingSoon
    }
}
