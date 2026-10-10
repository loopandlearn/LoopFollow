// LoopFollow
// IntentDataSource.swift

import Foundation

/// Gathers the app state an intent needs. Runs on the main actor because
/// `Storage` and `Observable` publish on the main thread.
@MainActor
enum IntentDataSource {
    /// Storage holds defaults during a suspected before-first-unlock launch and
    /// the App Group snapshot file is unreadable then, so intents refuse to answer.
    static func ensureStorageAvailable() throws {
        guard !StorageReadiness.isSuppressingWrites else {
            throw LoopFollowIntentError.storageUnavailable
        }
    }

    static func readoutInput(now: Date = Date()) throws -> StatusReadoutInput {
        try ensureStorageAvailable()

        // The live builder needs the in-memory glucose value, which is empty when
        // Siri launched the app in the background; the saved snapshot covers that.
        let live = Observable.shared.bg.value != nil
            ? GlucoseSnapshotBuilder.build(from: StorageCurrentGlucoseStateProvider())
            : nil
        let snapshot = live ?? GlucoseSnapshotStore.shared.load()

        return StatusReadoutInput(
            snapshot: snapshot,
            lastLoopTime: Storage.shared.lastLoopTime.value,
            loopAppName: Storage.shared.device.value,
            hasNightscout: !Storage.shared.url.value.isEmpty,
            alarms: alarmState(),
            now: now
        )
    }

    static func alarmState() -> AlarmStateInput {
        let config = Storage.shared.alarmConfiguration.value
        return AlarmStateInput(
            snoozeUntil: config.snoozeUntil,
            muteUntil: config.muteUntil,
            soundingAlarmName: soundingAlarm()?.name
        )
    }

    static func soundingAlarm() -> Alarm? {
        guard let id = Observable.shared.currentAlarm.value else { return nil }
        return Storage.shared.alarms.value.first { $0.id == id }
    }
}
