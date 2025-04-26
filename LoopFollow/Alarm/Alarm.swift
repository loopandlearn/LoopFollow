//
//  Alarm.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import HealthKit

enum PlaySoundOption: String, CaseIterable, Codable {
  case always, day, night, never
}
enum RepeatSoundOption: String, CaseIterable, Codable {
  case always, day, night, never
}
enum ActiveOption: String, CaseIterable, Codable {
  case always, day, night
}

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: AlarmType

    /// Name of the alarm, defaults to alarm type
    var name: String

    var isEnabled: Bool = true

    /// If the alarm is manually snoozed, we store the end time for the snooze here
    var snoozedUntil: Date?

    /// Alarm threashold, it can be a bgvalue (in mg/Dl), or day for example
    /// Also used as bg limit for drop alarms for example
    var threshold: Float?

    /// If the alarm looks at predictions, this is how many predictions to include
    var predictiveReadings: Int?

    /// If the alarm acts on delta, the delta is stored here, it can be a delta bgvalue (in mg/Dl)
    /// If a delta alarm is only active below a bg, that bg is stored in threshold
    var delta: Float?

    /// Number of consecutive 5‑min readings that must satisfy the alarm criteria
    var consecutiveReadings: Int?

    /// Size of window to observe values, for example battery drop of x within this number of minutes,
    var monitoringWindow: Int?

    var soundFile: SoundFile

    /// Snooze duration, it can be minutes, days or hours. Stepping is different per alarm type
    var snoozeDuration: Int = 5

    /// When the alarm should play it's sound
    var playSoundOption: PlaySoundOption = .always

    /// When the sound should repeat
    var repeatSoundOption: RepeatSoundOption = .always

    /// When is the alarm active
    var activeOption: ActiveOption = .always

    /// For temporary alerts, it will trigger once and then disable itself
    var disableAfterFiring: Bool = false

    // ─────────────────────────────────────────────────────────────
    //  Missed‑Bolus‑specific settings
    // ─────────────────────────────────────────────────────────────

    /// “Prebolus Max Time” (if a bolus comes within this many minutes *before* the carbs, treat it as prebolus)
    var missedBolusPrebolusWindow: Int?

    /// “Ignore Bolus <= X units” (don’t count any bolus smaller than or equal to this)
    var missedBolusIgnoreSmallBolusUnits: Float?

    /// “Ignore Under Grams” (if carb entry is under this many grams, skip the alert)
    var missedBolusIgnoreUnderGrams: Float?

    /// “Ignore Under BG” (if current BG is below this, skip the alert)
    var missedBolusIgnoreUnderBG: Float?

    // ─────────────────────────────────────────────────────────────
    // Bolus‑Count fields ─
    // ─────────────────────────────────────────────────────────────
    /// trigger when N or more of those boluses occur...
    var bolusCountThreshold: Int?
    /// ...within this many minutes
    var bolusWindowMinutes: Int?

    func checkCondition(data: AlarmData) -> Bool {
        return false
    }

    func trigger() {
        // TODO: play sound / update UI / schedule snooze etc.
        print("🔔 Alarm “\(name)” triggered! Playing \(soundFile.displayName)")
    }

    init(type: AlarmType) {
        self.type = type
        self.name = type.rawValue

        switch type {
        case .buildExpire:
            /// Alert 7 days before the build expires
            self.threshold = 7
            self.soundFile = .wrongAnswer
            self.snoozeDuration = 1
            self.repeatSoundOption = .always
        case .low:
            soundFile = .indeed
        case .iob:
            soundFile = .alertToneRingtone1
        case .bolus:
            soundFile = .dholShuffleloop
        case .cob:
            soundFile = .alertToneRingtone2
        case .high:
            soundFile = .timeHasCome
        case .fastDrop:
            soundFile = .bigClockTicking
        case .fastRise:
            soundFile = .cartoonFailStringsTrumpet
        case .missedReading:
            soundFile = .cartoonTipToeSneakyWalk
        case .notLooping:
            soundFile = .sciFiEngineShutDown
        case .missedBolus:
            soundFile = .dholShuffleloop
        case .sensorChange:
            soundFile = .wakeUpWillYou
        case .pumpChange:
            soundFile = .wakeUpWillYou
        case .pump:
            soundFile = .marimbaDescend
        case .battery:
            soundFile = .machineCharge
        case .batteryDrop:
            soundFile = .machineCharge
        case .recBolus:
            soundFile = .dholShuffleloop
        case .overrideStart:
            soundFile = .endingReached
        case .overrideEnd:
            soundFile = .alertToneBusy
        case .tempTargetStart:
            soundFile = .endingReached
        case .tempTargetEnd:
            soundFile = .alertToneBusy
        }
    }
}
