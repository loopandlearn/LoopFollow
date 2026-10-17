// LoopFollow
// CGMSensorStateTests.swift

import Foundation
@testable import LoopFollow
import Testing

struct CGMSensorStateTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func state(_ name: String, minutes: Double) -> CGMSensorState {
        CGMSensorState(name: name, date: t0.addingTimeInterval(minutes * 60))
    }

    private func reading(_ sgv: Int, minutes: Double) -> ShareGlucoseData {
        ShareGlucoseData(sgv: sgv, date: t0.addingTimeInterval(minutes * 60).timeIntervalSince1970, direction: nil)
    }

    // MARK: - Parsing

    @Test("Sensor-state notes parse to the kit's state name")
    func parsesSensorStateNotes() {
        #expect(CGMSensorState(note: "CGM: temporarySensorIssue", date: t0)?.name == "temporarySensorIssue")
        #expect(CGMSensorState(note: "CGM: warmup", date: t0)?.name == "warmup")
        #expect(CGMSensorState(note: "CGM: .unknown(23)", date: t0)?.name == ".unknown(23)")
    }

    @Test("Other notes are not sensor states")
    func ignoresOtherNotes() {
        #expect(CGMSensorState(note: "Pizza", date: t0) == nil)
        #expect(CGMSensorState(note: "CGM: ", date: t0) == nil)
        #expect(CGMSensorState(note: "CGM: sensor was wet after swim", date: t0) == nil)
        #expect(CGMSensorState(note: "cgm: warmup", date: t0) == nil)
    }

    // MARK: - Display names

    @Test("Kit names read as plain words")
    func displayNames() {
        #expect(CGMSensorState.displayName(for: "temporarySensorIssue") == "Temporary sensor issue")
        #expect(CGMSensorState.displayName(for: "warmup") == "Warmup")
        #expect(CGMSensorState.displayName(for: "sensorFailedDuetoCountsAberration") == "Sensor failed due to counts aberration")
        #expect(CGMSensorState.displayName(for: "firstOfTwoBGsNeeded") == "First of two BGs needed")
        #expect(CGMSensorState.displayName(for: "calibrationError8") == "Calibration error 8")
        #expect(CGMSensorState.displayName(for: "sensorFailure11") == "Sensor failure 11")
        #expect(CGMSensorState.displayName(for: "needCalibration7") == "Need calibration 7")
        #expect(CGMSensorState.displayName(for: "questionMarks") == "Question marks (???)")
        #expect(CGMSensorState.displayName(for: ".unknown(23)") == "Unknown state (23)")
    }

    // MARK: - Active state

    @Test("A state reported after the newest reading is active")
    func stateAfterReadingIsActive() {
        let issue = state("temporarySensorIssue", minutes: 5)
        #expect(CGMSensorState.active(in: [issue], latestBGDate: t0) == issue)
    }

    @Test("A reading after the state ends it")
    func readingAfterStateEndsIt() {
        let issue = state("temporarySensorIssue", minutes: 5)
        #expect(CGMSensorState.active(in: [issue], latestBGDate: t0.addingTimeInterval(20 * 60)) == nil)
    }

    @Test("A note stamped at the newest reading's time is not active")
    func noteAtReadingTimeIsNotActive() {
        let issue = state("temporarySensorIssue", minutes: 0)
        #expect(CGMSensorState.active(in: [issue], latestBGDate: t0) == nil)
    }

    @Test("The newest state wins")
    func newestStateWins() {
        let warmup = state("warmup", minutes: 1)
        let failed = state("sensorFailed", minutes: 6)
        let duplicate = state("warmup", minutes: 2)
        #expect(CGMSensorState.active(in: [failed, warmup, duplicate], latestBGDate: t0) == failed)
    }

    @Test("Without readings the newest state is active")
    func noReadings() {
        let failed = state("sensorFailed", minutes: 1)
        #expect(CGMSensorState.active(in: [failed], latestBGDate: nil) == failed)
        #expect(CGMSensorState.active(in: [], latestBGDate: nil) == nil)
    }

    // MARK: - Chart anchor

    @Test("The marker sits at the last reading before the state")
    func anchorsAtLastReadingBefore() {
        let readings = [reading(80, minutes: -10), reading(47, minutes: -5), reading(55, minutes: 15)]
        #expect(CGMSensorState.anchorSGV(at: t0.timeIntervalSince1970, readings: readings) == 47)
    }

    @Test("A state newer than every reading sits at the newest reading")
    func anchorsAfterNewestReading() {
        let readings = [reading(80, minutes: -10), reading(47, minutes: -5)]
        #expect(CGMSensorState.anchorSGV(at: t0.timeIntervalSince1970, readings: readings) == 47)
    }

    @Test("A state older than every reading sits at the first reading")
    func anchorsBeforeFirstReading() {
        let readings = [reading(120, minutes: 10)]
        #expect(CGMSensorState.anchorSGV(at: t0.timeIntervalSince1970, readings: readings) == 120)
        #expect(CGMSensorState.anchorSGV(at: t0.timeIntervalSince1970, readings: []) == nil)
    }
}
