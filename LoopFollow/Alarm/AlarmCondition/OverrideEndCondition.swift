// LoopFollow
// OverrideEndCondition.swift

import Foundation

struct OverrideEndCondition: AlarmCondition {
    static let type: AlarmType = .overrideEnd
    init() {}

    func evaluate(alarm _: Alarm, data: AlarmData, now: Date) -> Bool {
        guard let endTS = data.latestOverrideEnd, endTS > 0 else { return false }
        guard now.timeIntervalSince1970 - endTS <= 15 * 60 else { return false }

        let last = Storage.shared.lastOverrideEndNotified.value ?? 0
        guard endTS > last else { return false }

        Storage.shared.lastOverrideEndNotified.value = endTS
        return true
    }
}
