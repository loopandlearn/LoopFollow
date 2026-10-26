// LoopFollow
// TempTargetEndCondition.swift

import Foundation

/// Fires once when the active temp target ends and, with `predictiveMinutes`
/// set, once that many minutes before the scheduled end.
final class TempTargetEndCondition: AlarmCondition {
    static let type: AlarmType = .tempTargetEnd
    private(set) var firedTitle: String?
    init() {}

    func evaluate(alarm: Alarm, data: AlarmData, now: Date) -> Bool {
        let phase = EndAlarmPhases(
            latestStart: data.latestTempTargetStart,
            latestEnd: data.latestTempTargetEnd,
            activeEnd: data.activeTempTargetEnd,
            leadMinutes: alarm.predictiveMinutes,
            endedMarker: Storage.shared.lastTempTargetEndNotified,
            warnedMarker: Storage.shared.lastTempTargetPreEndNotified
        ).fire(now: now)
        firedTitle = phase == .endingSoon ? "Temp Target Ending Soon" : nil
        return phase != nil
    }
}
