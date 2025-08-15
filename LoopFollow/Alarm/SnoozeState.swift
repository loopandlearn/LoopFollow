// LoopFollow
// SnoozeState.swift

import Foundation

struct SnoozeState: Codable {
    var isSnoozed: Bool = false
    var snoozeUntil: Date?
}
