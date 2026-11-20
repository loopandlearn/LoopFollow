// LoopFollow
// AppIntentsIntegrationTests.swift

import AppIntents
import Foundation
@testable import LoopFollow
import Testing

/// Runs the intents inside the hosted app, so they read and write the real
/// Storage, Observable and App Group snapshot file.
@Suite(.serialized)
@MainActor
struct AppIntentsIntegrationTests {
    private func stringValue(_ result: some IntentResult) -> String? {
        (result as? IntentResultContainer<String, Never, Never, IntentDialog>)?.value
    }

    private func doubleValue(_ result: some IntentResult) -> Double? {
        (result as? IntentResultContainer<Double, Never, Never, IntentDialog>)?.value
    }

    /// Seeds the state a Siri cold launch sees: no in-memory glucose, a saved
    /// snapshot, and persisted Nightscout settings. Restores everything after `body`.
    private func withColdLaunchState(_ body: () async throws -> Void) async throws {
        let previousBg = Observable.shared.bg.value
        let previousUrl = Storage.shared.url.value
        let previousLoop = Storage.shared.lastLoopTime.value
        let previousDevice = Storage.shared.device.value
        let previousSnapshot = GlucoseSnapshotStore.shared.load()
        defer {
            Observable.shared.bg.value = previousBg
            Storage.shared.url.value = previousUrl
            Storage.shared.lastLoopTime.value = previousLoop
            Storage.shared.device.value = previousDevice
            if let previousSnapshot {
                GlucoseSnapshotStore.shared.save(previousSnapshot)
            } else {
                GlucoseSnapshotStore.shared.delete()
            }
        }

        Observable.shared.bg.value = nil
        Storage.shared.url.value = "http://127.0.0.1:1"
        Storage.shared.lastLoopTime.value = Date().timeIntervalSince1970 - 4 * 60
        Storage.shared.device.value = "Loop"
        GlucoseSnapshotStore.shared.save(GlucoseSnapshot(
            glucose: 115,
            delta: 5,
            trend: .upSlight,
            updatedAt: Date().addingTimeInterval(-3 * 60),
            iob: 1.25,
            cob: 15,
            projected: nil,
            unit: .mmol,
            isNotLooping: false
        ))
        try await Task.sleep(for: .milliseconds(500))

        try await body()
    }

    @Test("status intent reads the saved snapshot when no live glucose is in memory")
    func statusFromSavedSnapshot() async throws {
        try await withColdLaunchState {
            let result = try await GetStatusIntent().perform()
            #expect(stringValue(result) == "Glucose is 6.4, rising slowly, up 0.3, 3 minutes ago. IOB is 1.25 units. COB is 15 grams. The loop last completed 4 minutes ago.")
        }
    }

    @Test("glucose intent returns the number in display units")
    func glucoseValue() async throws {
        try await withColdLaunchState {
            let result = try await GetGlucoseIntent().perform()
            #expect(doubleValue(result) == 6.4)
        }
    }

    @Test("item intent answers a single field")
    func itemIntent() async throws {
        try await withColdLaunchState {
            var intent = GetStatusItemIntent()
            intent.item = .iob
            let iob = try await intent.perform()
            #expect(stringValue(iob) == "IOB is 1.25 units.")
            intent.item = .lastLoop
            let lastLoop = try await intent.perform()
            #expect(stringValue(lastLoop) == "The loop last completed 4 minutes ago.")
            intent.item = .recommendedBolus
            let recBolus = try await intent.perform()
            #expect(stringValue(recBolus) == "No recommended bolus is reported.")
        }
    }

    @Test("snooze all, end snooze, mute and unmute update the alarm configuration")
    func snoozeIntents() async throws {
        let previous = Storage.shared.alarmConfiguration.value
        defer { Storage.shared.alarmConfiguration.value = previous }

        var snooze = SnoozeAllAlarmsIntent()
        snooze.duration = .twoHours
        _ = try await snooze.perform()
        let until = try #require(Storage.shared.alarmConfiguration.value.snoozeUntil)
        #expect(abs(until.timeIntervalSinceNow - 2 * 60 * 60) < 5)

        _ = try await EndSnoozeIntent().perform()
        #expect(Storage.shared.alarmConfiguration.value.snoozeUntil == nil)

        var mute = MuteAlarmSoundsIntent()
        mute.duration = .thirtyMinutes
        _ = try await mute.perform()
        let mutedUntil = try #require(Storage.shared.alarmConfiguration.value.muteUntil)
        #expect(abs(mutedUntil.timeIntervalSinceNow - 30 * 60) < 5)

        _ = try await UnmuteAlarmSoundsIntent().perform()
        #expect(Storage.shared.alarmConfiguration.value.muteUntil == nil)
    }

    @Test("snoozing the current alarm with none sounding leaves alarms untouched")
    func snoozeCurrentWithoutAlarm() async throws {
        let previousAlarms = Storage.shared.alarms.value
        Observable.shared.currentAlarm.value = nil
        _ = try await SnoozeCurrentAlarmIntent().perform()
        #expect(Storage.shared.alarms.value == previousAlarms)
    }
}
