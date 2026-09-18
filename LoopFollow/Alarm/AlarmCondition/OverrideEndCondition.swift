// LoopFollow
// OverrideEndCondition.swift

import Foundation

/// Fires once when the active override ends and, with `predictiveMinutes`
/// set, once that many minutes before the scheduled end.
final class OverrideEndCondition: AlarmCondition {
    static let type: AlarmType = .overrideEnd
    private(set) var firedTitle: String?
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        let phase = EndAlarmPhases(
            latestStart: data.latestOverrideStart,
            latestEnd: data.latestOverrideEnd,
            activeEnd: data.activeOverrideEnd,
            leadMinutes: alarm.predictiveMinutes,
            endedMarker: Storage.shared.lastOverrideEndNotified,
            warnedMarker: Storage.shared.lastOverridePreEndNotified
        ).fire(now: now)
        firedTitle = phase == .endingSoon ? "Override Ending Soon" : nil
        return phase != nil
    }
}
