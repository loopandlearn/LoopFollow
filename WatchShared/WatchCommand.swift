// LoopFollow
// WatchCommand.swift

import Foundation

/// A request from the watch. The phone validates it against its own settings and
/// guardrails and sends it with the same code path as its Remote screens.
struct WatchCommand: Codable, Equatable {
    static let messageKey = "watchCommand"
    /// The phone ignores commands older than this, so a delayed delivery is never acted on.
    static let maxAge: TimeInterval = 60

    enum Action: Codable, Equatable {
        case bolus(units: Double)
        /// Loop sends carbs only; Trio may add fat, protein and a bolus in the same command.
        case meal(carbs: Double, fat: Double, protein: Double, bolus: Double, consumedAt: Date)
        case startOverride(presetID: String)
        case cancelOverride
        case startTempTarget(presetID: String)
        case cancelTempTarget
        case snoozeAlarm
    }

    let id: UUID
    let createdAt: Date
    let action: Action

    init(action: Action) {
        id = UUID()
        createdAt = Date()
        self.action = action
    }
}

struct WatchCommandReply: Codable, Equatable {
    static let messageKey = "watchCommandReply"

    let success: Bool
    let message: String
}

enum WatchMessageKey {
    /// Watch → phone: asks for the current state; the reply carries `WatchState.contextKey`.
    static let requestState = "requestState"
}
