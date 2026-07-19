// LoopFollow
// SoundFile.swift

import Foundation

/// A sound chosen for an alarm.
///
/// `.builtin` wraps the filename (no extension) of a `.caf` resource bundled with the app.
/// `.custom` references an audio file imported by the user into `Documents/CustomSounds/`,
/// keyed by UUID (see `CustomSoundStore`).
///
/// Codable note: built-in values encode/decode as a bare string (e.g. `"Indeed"`) so stored
/// alarm data written by older app versions continues to load. Custom values encode as a
/// keyed object and are new with this version.
enum SoundFile: Hashable, Identifiable {
    case builtin(String)
    case custom(UUID)

    var id: String {
        switch self {
        case let .builtin(name): return "builtin:\(name)"
        case let .custom(uuid): return "custom:\(uuid.uuidString)"
        }
    }

    /// Human-friendly name for display in pickers.
    var displayName: String {
        switch self {
        case let .builtin(name):
            return name
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
        case let .custom(uuid):
            return CustomSoundStore.shared.displayName(for: uuid) ?? "Custom Sound"
        }
    }

    /// Convenience for call sites that still think in terms of a bundle filename.
    var builtinName: String? {
        if case let .builtin(name) = self { return name }
        return nil
    }

    /// Back-compat shim for migration code that reads legacy string values out of UserDefaults.
    /// The string is treated as a built-in filename; playback will fall back gracefully if the
    /// file isn't actually in the bundle.
    init?(rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self = .builtin(rawValue)
    }
}

extension SoundFile: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, name, id
    }

    init(from decoder: Decoder) throws {
        // Legacy form: bare string == built-in filename.
        if let container = try? decoder.singleValueContainer(),
           let name = try? container.decode(String.self)
        {
            self = .builtin(name)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "builtin":
            let name = try c.decode(String.self, forKey: .name)
            self = .builtin(name)
        case "custom":
            let uuid = try c.decode(UUID.self, forKey: .id)
            self = .custom(uuid)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: c,
                debugDescription: "Unknown SoundFile kind: \(kind)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .builtin(name):
            // Preserve legacy wire format so older app versions can still read it.
            var c = encoder.singleValueContainer()
            try c.encode(name)
        case let .custom(uuid):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("custom", forKey: .kind)
            try c.encode(uuid, forKey: .id)
        }
    }
}

// MARK: - Built-in catalog

extension SoundFile {
    /// Fallback used when a referenced sound file can't be located (e.g. a deleted custom sound).
    static let fallback: SoundFile = .indeed

    /// Every built-in sound shipped with the app, in the order shown in the picker.
    static let allBuiltins: [SoundFile] = [
        .alarmBuzzer, .alarmClock, .alertToneBusy, .alertToneRingtone1, .alertToneRingtone2,
        .alienSiren, .ambulance, .analogWatchAlarm, .bigClockTicking, .burglarAlarmSiren1,
        .burglarAlarmSiren2, .cartoonAscendClimbSneaky, .cartoonAscendThenDescend,
        .cartoonBounceToCeiling, .cartoonDreamyGlissandoHarp, .cartoonFailStringsTrumpet,
        .cartoonMachineClumsyLoop, .cartoonSiren, .cartoonTipToeSneakyWalk, .cartoonUhOh,
        .cartoonVillainHorns, .cellPhoneRingTone, .chimesGlassy, .computerMagic, .csfx2Alarm,
        .cuckooClock, .dholShuffleloop, .discreet, .earlySunrise, .emergencyAlarmCarbonMonoxide,
        .emergencyAlarmSiren, .emergencyAlarm, .endingReached, .fly, .ghostHover, .goodMorning,
        .hellYeahSomewhatCalmer, .inAHurry, .indeed, .insistently, .jingleAllTheWay, .laserShoot,
        .machineCharge, .magicalTwinkle, .marchingHeavyFootedFatElephants, .marimbaDescend,
        .marimbaFlutterOrShake, .martianGun, .martianScanner, .metallic, .nightguard, .notKiddin,
        .openYourEyesAndSee, .orchestralHorns, .oringz, .pagerBeeps, .remembersMeOfAsia,
        .riseAndShine, .rush, .sciFiAirRaidAlarm, .sciFiAlarmLoop1, .sciFiAlarmLoop2,
        .sciFiAlarmLoop3, .sciFiAlarmLoop4, .sciFiAlarm, .sciFiComputerConsoleAlarm,
        .sciFiConsoleAlarm, .sciFiEerieAlarm, .sciFiEngineShutDown, .sciFiIncomingMessageAlert,
        .sciFiSpaceshipMessage, .sciFiSpaceshipWarmUp, .sciFiWarning, .signatureCorporate,
        .siriAlertCalibrationNeeded, .siriAlertDeviceMuted, .siriAlertGlucoseDroppingFast,
        .siriAlertGlucoseRisingFast, .siriAlertHighGlucose, .siriAlertLowGlucose,
        .siriAlertMissedReadings, .siriAlertTransmitterBatteryLow, .siriAlertUrgentHighGlucose,
        .siriAlertUrgentLowGlucose, .siriCalibrationNeeded, .siriDeviceMuted,
        .siriGlucoseDroppingFast, .siriGlucoseRisingFast, .siriHighGlucose, .siriLowGlucose,
        .siriMissedReadings, .siriTransmitterBatteryLow, .siriUrgentHighGlucose,
        .siriUrgentLowGlucose, .softMarimbaPadPositive, .softWarmAiryOptimistic,
        .softWarmAiryReassuring, .storeDoorChime, .sunny, .thunderSoundFX, .timeHasCome,
        .tornadoSiren, .twoTurtleDoves, .unpaved, .wakeUpWillYou, .winGain, .wrongAnswer,
    ]

    // Static aliases so existing call sites like `soundFile = .indeed` keep compiling.
    static let alarmBuzzer: SoundFile = .builtin("Alarm_Buzzer")
    static let alarmClock: SoundFile = .builtin("Alarm_Clock")
    static let alertToneBusy: SoundFile = .builtin("Alert_Tone_Busy")
    static let alertToneRingtone1: SoundFile = .builtin("Alert_Tone_Ringtone_1")
    static let alertToneRingtone2: SoundFile = .builtin("Alert_Tone_Ringtone_2")
    static let alienSiren: SoundFile = .builtin("Alien_Siren")
    static let ambulance: SoundFile = .builtin("Ambulance")
    static let analogWatchAlarm: SoundFile = .builtin("Analog_Watch_Alarm")
    static let bigClockTicking: SoundFile = .builtin("Big_Clock_Ticking")
    static let burglarAlarmSiren1: SoundFile = .builtin("Burglar_Alarm_Siren_1")
    static let burglarAlarmSiren2: SoundFile = .builtin("Burglar_Alarm_Siren_2")
    static let cartoonAscendClimbSneaky: SoundFile = .builtin("Cartoon_Ascend_Climb_Sneaky")
    static let cartoonAscendThenDescend: SoundFile = .builtin("Cartoon_Ascend_Then_Descend")
    static let cartoonBounceToCeiling: SoundFile = .builtin("Cartoon_Bounce_To_Ceiling")
    static let cartoonDreamyGlissandoHarp: SoundFile = .builtin("Cartoon_Dreamy_Glissando_Harp")
    static let cartoonFailStringsTrumpet: SoundFile = .builtin("Cartoon_Fail_Strings_Trumpet")
    static let cartoonMachineClumsyLoop: SoundFile = .builtin("Cartoon_Machine_Clumsy_Loop")
    static let cartoonSiren: SoundFile = .builtin("Cartoon_Siren")
    static let cartoonTipToeSneakyWalk: SoundFile = .builtin("Cartoon_Tip_Toe_Sneaky_Walk")
    static let cartoonUhOh: SoundFile = .builtin("Cartoon_Uh_Oh")
    static let cartoonVillainHorns: SoundFile = .builtin("Cartoon_Villain_Horns")
    static let cellPhoneRingTone: SoundFile = .builtin("Cell_Phone_Ring_Tone")
    static let chimesGlassy: SoundFile = .builtin("Chimes_Glassy")
    static let computerMagic: SoundFile = .builtin("Computer_Magic")
    static let csfx2Alarm: SoundFile = .builtin("CSFX-2_Alarm")
    static let cuckooClock: SoundFile = .builtin("Cuckoo_Clock")
    static let dholShuffleloop: SoundFile = .builtin("Dhol_Shuffleloop")
    static let discreet: SoundFile = .builtin("Discreet")
    static let earlySunrise: SoundFile = .builtin("Early_Sunrise")
    static let emergencyAlarmCarbonMonoxide: SoundFile = .builtin("Emergency_Alarm_Carbon_Monoxide")
    static let emergencyAlarmSiren: SoundFile = .builtin("Emergency_Alarm_Siren")
    static let emergencyAlarm: SoundFile = .builtin("Emergency_Alarm")
    static let endingReached: SoundFile = .builtin("Ending_Reached")
    static let fly: SoundFile = .builtin("Fly")
    static let ghostHover: SoundFile = .builtin("Ghost_Hover")
    static let goodMorning: SoundFile = .builtin("Good_Morning")
    static let hellYeahSomewhatCalmer: SoundFile = .builtin("Hell_Yeah_Somewhat_Calmer")
    static let inAHurry: SoundFile = .builtin("In_A_Hurry")
    static let indeed: SoundFile = .builtin("Indeed")
    static let insistently: SoundFile = .builtin("Insistently")
    static let jingleAllTheWay: SoundFile = .builtin("Jingle_All_The_Way")
    static let laserShoot: SoundFile = .builtin("Laser_Shoot")
    static let machineCharge: SoundFile = .builtin("Machine_Charge")
    static let magicalTwinkle: SoundFile = .builtin("Magical_Twinkle")
    static let marchingHeavyFootedFatElephants: SoundFile = .builtin("Marching_Heavy_Footed_Fat_Elephants")
    static let marimbaDescend: SoundFile = .builtin("Marimba_Descend")
    static let marimbaFlutterOrShake: SoundFile = .builtin("Marimba_Flutter_or_Shake")
    static let martianGun: SoundFile = .builtin("Martian_Gun")
    static let martianScanner: SoundFile = .builtin("Martian_Scanner")
    static let metallic: SoundFile = .builtin("Metallic")
    static let nightguard: SoundFile = .builtin("Nightguard")
    static let notKiddin: SoundFile = .builtin("Not_Kiddin")
    static let openYourEyesAndSee: SoundFile = .builtin("Open_Your_Eyes_And_See")
    static let orchestralHorns: SoundFile = .builtin("Orchestral_Horns")
    static let oringz: SoundFile = .builtin("Oringz")
    static let pagerBeeps: SoundFile = .builtin("Pager_Beeps")
    static let remembersMeOfAsia: SoundFile = .builtin("Remembers_Me_Of_Asia")
    static let riseAndShine: SoundFile = .builtin("Rise_And_Shine")
    static let rush: SoundFile = .builtin("Rush")
    static let sciFiAirRaidAlarm: SoundFile = .builtin("Sci-Fi_Air_Raid_Alarm")
    static let sciFiAlarmLoop1: SoundFile = .builtin("Sci-Fi_Alarm_Loop_1")
    static let sciFiAlarmLoop2: SoundFile = .builtin("Sci-Fi_Alarm_Loop_2")
    static let sciFiAlarmLoop3: SoundFile = .builtin("Sci-Fi_Alarm_Loop_3")
    static let sciFiAlarmLoop4: SoundFile = .builtin("Sci-Fi_Alarm_Loop_4")
    static let sciFiAlarm: SoundFile = .builtin("Sci-Fi_Alarm")
    static let sciFiComputerConsoleAlarm: SoundFile = .builtin("Sci-Fi_Computer_Console_Alarm")
    static let sciFiConsoleAlarm: SoundFile = .builtin("Sci-Fi_Console_Alarm")
    static let sciFiEerieAlarm: SoundFile = .builtin("Sci-Fi_Eerie_Alarm")
    static let sciFiEngineShutDown: SoundFile = .builtin("Sci-Fi_Engine_Shut_Down")
    static let sciFiIncomingMessageAlert: SoundFile = .builtin("Sci-Fi_Incoming_Message_Alert")
    static let sciFiSpaceshipMessage: SoundFile = .builtin("Sci-Fi_Spaceship_Message")
    static let sciFiSpaceshipWarmUp: SoundFile = .builtin("Sci-Fi_Spaceship_Warm_Up")
    static let sciFiWarning: SoundFile = .builtin("Sci-Fi_Warning")
    static let signatureCorporate: SoundFile = .builtin("Signature_Corporate")
    static let siriAlertCalibrationNeeded: SoundFile = .builtin("Siri_Alert_Calibration_Needed")
    static let siriAlertDeviceMuted: SoundFile = .builtin("Siri_Alert_Device_Muted")
    static let siriAlertGlucoseDroppingFast: SoundFile = .builtin("Siri_Alert_Glucose_Dropping_Fast")
    static let siriAlertGlucoseRisingFast: SoundFile = .builtin("Siri_Alert_Glucose_Rising_Fast")
    static let siriAlertHighGlucose: SoundFile = .builtin("Siri_Alert_High_Glucose")
    static let siriAlertLowGlucose: SoundFile = .builtin("Siri_Alert_Low_Glucose")
    static let siriAlertMissedReadings: SoundFile = .builtin("Siri_Alert_Missed_Readings")
    static let siriAlertTransmitterBatteryLow: SoundFile = .builtin("Siri_Alert_Transmitter_Battery_Low")
    static let siriAlertUrgentHighGlucose: SoundFile = .builtin("Siri_Alert_Urgent_High_Glucose")
    static let siriAlertUrgentLowGlucose: SoundFile = .builtin("Siri_Alert_Urgent_Low_Glucose")
    static let siriCalibrationNeeded: SoundFile = .builtin("Siri_Calibration_Needed")
    static let siriDeviceMuted: SoundFile = .builtin("Siri_Device_Muted")
    static let siriGlucoseDroppingFast: SoundFile = .builtin("Siri_Glucose_Dropping_Fast")
    static let siriGlucoseRisingFast: SoundFile = .builtin("Siri_Glucose_Rising_Fast")
    static let siriHighGlucose: SoundFile = .builtin("Siri_High_Glucose")
    static let siriLowGlucose: SoundFile = .builtin("Siri_Low_Glucose")
    static let siriMissedReadings: SoundFile = .builtin("Siri_Missed_Readings")
    static let siriTransmitterBatteryLow: SoundFile = .builtin("Siri_Transmitter_Battery_Low")
    static let siriUrgentHighGlucose: SoundFile = .builtin("Siri_Urgent_High_Glucose")
    static let siriUrgentLowGlucose: SoundFile = .builtin("Siri_Urgent_Low_Glucose")
    static let softMarimbaPadPositive: SoundFile = .builtin("Soft_Marimba_Pad_Positive")
    static let softWarmAiryOptimistic: SoundFile = .builtin("Soft_Warm_Airy_Optimistic")
    static let softWarmAiryReassuring: SoundFile = .builtin("Soft_Warm_Airy_Reassuring")
    static let storeDoorChime: SoundFile = .builtin("Store_Door_Chime")
    static let sunny: SoundFile = .builtin("Sunny")
    static let thunderSoundFX: SoundFile = .builtin("Thunder_Sound_FX")
    static let timeHasCome: SoundFile = .builtin("Time_Has_Come")
    static let tornadoSiren: SoundFile = .builtin("Tornado_Siren")
    static let twoTurtleDoves: SoundFile = .builtin("Two_Turtle_Doves")
    static let unpaved: SoundFile = .builtin("Unpaved")
    static let wakeUpWillYou: SoundFile = .builtin("Wake_Up_Will_You")
    static let winGain: SoundFile = .builtin("Win_Gain")
    static let wrongAnswer: SoundFile = .builtin("Wrong_Answer")
}
