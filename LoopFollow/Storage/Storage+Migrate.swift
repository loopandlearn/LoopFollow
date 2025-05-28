// LoopFollow
// Storage+Migrate.swift
// Created by Jonas Björkert on 2025-05-26.

import Foundation

extension Storage {
    func migrate() {
        // Helper: 1-to-1 type -----------------------------------------------------------------
        func move<T: AnyConvertible & Equatable>(
            _ legacy: @autoclosure () -> UserDefaultsValue<T>,
            into newValue: StorageValue<T>
        ) {
            let item = legacy()
            guard item.exists else { return }
            newValue.value = item.value
            item.setNil(key: item.key)
        }

        // Helper: Float  →  Double ------------------------------------------------------------
        func moveFloatToDouble(
            _ legacy: @autoclosure () -> UserDefaultsValue<Float>,
            into newValue: StorageValue<Double>
        ) {
            let item = legacy()
            guard item.exists else { return }
            newValue.value = Double(item.value)
            item.setNil(key: item.key)
        }

        if !UserDefaultsRepository.backgroundRefresh.value {
            Storage.shared.backgroundRefreshType.value = .none
            UserDefaultsRepository.backgroundRefresh.value = true
        }

        // Remove this in a year later than the release of the new Alarms [BEGIN]
        let legacyColorBGText = UserDefaultsValue<Bool>(key: "colorBGText", default: true)
        if legacyColorBGText.exists {
            Storage.shared.colorBGText.value = legacyColorBGText.value
            legacyColorBGText.setNil(key: "colorBGText")
        }

        let legacyAppBadge = UserDefaultsValue<Bool>(key: "appBadge", default: true)
        if legacyAppBadge.exists {
            Storage.shared.appBadge.value = legacyAppBadge.value
            legacyAppBadge.setNil(key: "appBadge")
        }

        let legacyForceDarkMode = UserDefaultsValue<Bool>(key: "forceDarkMode", default: true)
        if legacyForceDarkMode.exists {
            Storage.shared.forceDarkMode.value = legacyForceDarkMode.value
            legacyForceDarkMode.setNil(key: "forceDarkMode")
        }

        let legacyShowStats = UserDefaultsValue<Bool>(key: "showStats", default: true)
        if legacyShowStats.exists {
            Storage.shared.showStats.value = legacyShowStats.value
            legacyShowStats.setNil(key: "showStats")
        }

        let legacyUseIFCC = UserDefaultsValue<Bool>(key: "useIFCC", default: false)
        if legacyUseIFCC.exists {
            Storage.shared.useIFCC.value = legacyUseIFCC.value
            legacyUseIFCC.setNil(key: "useIFCC")
        }

        let legacyShowSmallGraph = UserDefaultsValue<Bool>(key: "showSmallGraph", default: true)
        if legacyShowSmallGraph.exists {
            Storage.shared.showSmallGraph.value = legacyShowSmallGraph.value
            legacyShowSmallGraph.setNil(key: "showSmallGraph")
        }

        let legacyScreenlockSwitchState = UserDefaultsValue<Bool>(key: "screenlockSwitchState", default: true)
        if legacyScreenlockSwitchState.exists {
            Storage.shared.screenlockSwitchState.value = legacyScreenlockSwitchState.value
            legacyScreenlockSwitchState.setNil(key: "screenlockSwitchState")
        }

        let legacyShowDisplayName = UserDefaultsValue<Bool>(key: "showDisplayName", default: false)
        if legacyShowDisplayName.exists {
            Storage.shared.showDisplayName.value = legacyShowDisplayName.value
            legacyShowDisplayName.setNil(key: "showDisplayName")
        }

        let legacySpeakBG = UserDefaultsValue<Bool>(key: "speakBG", default: false)
        if legacySpeakBG.exists {
            Storage.shared.speakBG.value = legacySpeakBG.value
            legacySpeakBG.setNil(key: "speakBG")
        }

        let legacySpeakBGAlways = UserDefaultsValue<Bool>(key: "speakBGAlways", default: true)
        if legacySpeakBGAlways.exists {
            Storage.shared.speakBGAlways.value = legacySpeakBGAlways.value
            legacySpeakBGAlways.setNil(key: "speakBGAlways")
        }

        let legacySpeakLowBG = UserDefaultsValue<Bool>(key: "speakLowBG", default: false)
        if legacySpeakLowBG.exists {
            Storage.shared.speakLowBG.value = legacySpeakLowBG.value
            legacySpeakLowBG.setNil(key: "speakLowBG")
        }

        let legacySpeakProactiveLowBG = UserDefaultsValue<Bool>(key: "speakProactiveLowBG", default: false)
        if legacySpeakProactiveLowBG.exists {
            Storage.shared.speakProactiveLowBG.value = legacySpeakProactiveLowBG.value
            legacySpeakProactiveLowBG.setNil(key: "speakProactiveLowBG")
        }

        let legacySpeakFastDropDelta = UserDefaultsValue<Float>(key: "speakFastDropDelta", default: 10.0)
        if legacySpeakFastDropDelta.exists {
            Storage.shared.speakFastDropDelta.value = Double(legacySpeakFastDropDelta.value)
            legacySpeakFastDropDelta.setNil(key: "speakFastDropDelta")
        }

        let legacySpeakLowBGLimit = UserDefaultsValue<Float>(key: "speakLowBGLimit", default: 72.0)
        if legacySpeakLowBGLimit.exists {
            Storage.shared.speakLowBGLimit.value = Double(legacySpeakLowBGLimit.value)
            legacySpeakLowBGLimit.setNil(key: "speakLowBGLimit")
        }

        let legacySpeakHighBGLimit = UserDefaultsValue<Float>(key: "speakHighBGLimit", default: 180.0)
        if legacySpeakHighBGLimit.exists {
            Storage.shared.speakHighBGLimit.value = Double(legacySpeakHighBGLimit.value)
            legacySpeakHighBGLimit.setNil(key: "speakHighBGLimit")
        }

        let legacySpeakHighBG = UserDefaultsValue<Bool>(key: "speakHighBG", default: false)
        if legacySpeakHighBG.exists {
            Storage.shared.speakHighBG.value = legacySpeakHighBG.value
            legacySpeakHighBG.setNil(key: "speakHighBG")
        }

        let legacySpeakLanguage = UserDefaultsValue<String>(key: "speakLanguage", default: "en")
        if legacySpeakLanguage.exists {
            Storage.shared.speakLanguage.value = legacySpeakLanguage.value
            legacySpeakLanguage.setNil(key: "speakLanguage")
        }

        // ── General (done earlier, but safe to repeat) ──
        move(UserDefaultsValue<Bool>(key: "colorBGText", default: true), into: Storage.shared.colorBGText)
        move(UserDefaultsValue<Bool>(key: "appBadge", default: true), into: appBadge)
        move(UserDefaultsValue<Bool>(key: "forceDarkMode", default: false), into: forceDarkMode)
        move(UserDefaultsValue<Bool>(key: "showStats", default: true), into: showStats)
        move(UserDefaultsValue<Bool>(key: "useIFCC", default: false), into: useIFCC)
        move(UserDefaultsValue<Bool>(key: "showSmallGraph", default: true), into: showSmallGraph)
        move(UserDefaultsValue<Bool>(key: "screenlockSwitchState", default: false), into: screenlockSwitchState)
        move(UserDefaultsValue<Bool>(key: "showDisplayName", default: false), into: showDisplayName)

        // ── Speak-BG ──
        move(UserDefaultsValue<Bool>(key: "speakBG", default: false), into: speakBG)
        move(UserDefaultsValue<Bool>(key: "speakBGAlways", default: true), into: speakBGAlways)
        move(UserDefaultsValue<Bool>(key: "speakLowBG", default: false), into: speakLowBG)
        move(UserDefaultsValue<Bool>(key: "speakProactiveLowBG", default: false), into: speakProactiveLowBG)
        move(UserDefaultsValue<Bool>(key: "speakHighBG", default: false), into: speakHighBG)
        moveFloatToDouble(UserDefaultsValue<Float>(key: "speakLowBGLimit", default: 72.0), into: speakLowBGLimit)
        moveFloatToDouble(UserDefaultsValue<Float>(key: "speakHighBGLimit", default: 180.0), into: speakHighBGLimit)
        moveFloatToDouble(UserDefaultsValue<Float>(key: "speakFastDropDelta", default: 10.0), into: speakFastDropDelta)
        move(UserDefaultsValue<String>(key: "speakLanguage", default: "en"), into: speakLanguage)

        // ── Graph ──
        move(UserDefaultsValue<Bool>(key: "showDots", default: true), into: showDots)
        move(UserDefaultsValue<Bool>(key: "showLines", default: true), into: showLines)
        move(UserDefaultsValue<Bool>(key: "showValues", default: true), into: showValues)
        move(UserDefaultsValue<Bool>(key: "showAbsorption", default: true), into: showAbsorption)
        move(UserDefaultsValue<Bool>(key: "showDIAMarkers", default: true), into: showDIALines)
        move(UserDefaultsValue<Bool>(key: "show30MinLine", default: false), into: show30MinLine)
        move(UserDefaultsValue<Bool>(key: "show90MinLine", default: false), into: show90MinLine)
        move(UserDefaultsValue<Bool>(key: "showMidnightMarkers", default: false), into: showMidnightLines)
        move(UserDefaultsValue<Bool>(key: "smallGraphTreatments", default: true), into: smallGraphTreatments)

        move(UserDefaultsValue<Int>(key: "smallGraphHeight", default: 40), into: smallGraphHeight)
        move(UserDefaultsValue<Double>(key: "predictionToLoad", default: 1.0), into: predictionToLoad)
        move(UserDefaultsValue<Double>(key: "minBasalScale", default: 5.0), into: minBasalScale)
        moveFloatToDouble(UserDefaultsValue<Float>(key: "minBGScale", default: 250.0), into: minBGScale)
        moveFloatToDouble(UserDefaultsValue<Float>(key: "lowLine", default: 70.0), into: lowLine)
        moveFloatToDouble(UserDefaultsValue<Float>(key: "highLine", default: 180.0), into: highLine)
        move(UserDefaultsValue<Int>(key: "downloadDays", default: 1), into: downloadDays)
        // Remove this in a year later than the release of the new Alarms [END]

        // ── Watch / Calendar ────────────────────────────────────────────────
        move(UserDefaultsValue<Bool>(key: "writeCalendarEvent", default: false), into: writeCalendarEvent)
        move(UserDefaultsValue<String>(key: "calendarIdentifier", default: ""), into: calendarIdentifier)
        move(UserDefaultsValue<String>(key: "watchLine1", default: "%BG% %DIRECTION% %DELTA% %MINAGO%"), into: watchLine1)
        move(UserDefaultsValue<String>(key: "watchLine2", default: "C:%COB% I:%IOB% B:%BASAL%"), into: watchLine2)

        // Migration of generic alarm settings
        // ── AlarmConfiguration migration ─────────────────────────────────────────
        do {
            // Work on a mutable copy, then write the whole thing back once.
            var cfg = Storage.shared.alarmConfiguration.value
            let cal = Calendar.current

            /// Copy *one* legacy value → struct field → delete old key
            func move<T: AnyConvertible & Equatable>(
                _ legacy: @autoclosure () -> UserDefaultsValue<T>,
                write: (inout AlarmConfiguration, T) -> Void
            ) {
                let item = legacy()
                guard item.exists else { return }
                write(&cfg, item.value)
                item.setNil(key: item.key)
            }

            // 1.  Override-volume toggle
            move(UserDefaultsValue<Bool>(key: "overrideSystemOutputVolume",
                                         default: cfg.overrideSystemOutputVolume))
            {
                $0.overrideSystemOutputVolume = $1
            }

            // 2.  Forced output volume itself.
            //     Prefer newer key (“forcedOutputVolume”); otherwise fall back.
            if UserDefaultsValue<Float>(key: "forcedOutputVolume",
                                        default: cfg.forcedOutputVolume).exists
            {
                move(UserDefaultsValue<Float>(key: "forcedOutputVolume",
                                              default: cfg.forcedOutputVolume))
                {
                    $0.forcedOutputVolume = $1
                }
            } else {
                move(UserDefaultsValue<Float>(key: "systemOutputVolume",
                                              default: cfg.forcedOutputVolume))
                {
                    $0.forcedOutputVolume = $1
                }
            }

            // 3.  Play audio during phone calls
            move(UserDefaultsValue<Bool>(key: "alertAudioDuringPhone",
                                         default: cfg.audioDuringCalls))
            {
                $0.audioDuringCalls = $1
            }

            // 4.  Auto-snooze CGM-start alarm
            move(UserDefaultsValue<Bool>(key: "alertAutoSnoozeCGMStart",
                                         default: cfg.autoSnoozeCGMStart))
            {
                $0.autoSnoozeCGMStart = $1
            }

            // 5.  Global “Snooze all”  →  snoozeUntil
            move(UserDefaultsValue<Date?>(key: "alertSnoozeAllTime",
                                          default: cfg.snoozeUntil))
            {
                $0.snoozeUntil = $1
            }

            // 6.  Global “Mute all”  →  muteUntil
            move(UserDefaultsValue<Date?>(key: "alertMuteAllTime",
                                          default: cfg.muteUntil))
            {
                $0.muteUntil = $1
            }

            // 7 & 8.  Legacy quiet-hours → day/night start
            //         (only if both dates exist and are on the same “reference” day)
            let qStart = UserDefaultsValue<Date?>(key: "quietHourStart", default: nil)
            let qEnd = UserDefaultsValue<Date?>(key: "quietHourEnd", default: nil)
            if let s = qStart.value, let e = qEnd.value {
                let compsStart = cal.dateComponents([.hour, .minute], from: s)
                let compsEnd = cal.dateComponents([.hour, .minute], from: e)

                if let sh = compsStart.hour, let sm = compsStart.minute,
                   let eh = compsEnd.hour, let em = compsEnd.minute
                {
                    cfg.nightStart = TimeOfDay(hour: sh, minute: sm)
                    cfg.dayStart = TimeOfDay(hour: eh, minute: em)
                    qStart.setNil(key: qStart.key)
                    qEnd.setNil(key: qEnd.key)
                }
            }

            // 9.  Legacy “ignore zero BG” flag  →  ignoreZeroBG
            move(UserDefaultsValue<Bool>(key: "alertIgnoreZero",
                                         default: cfg.ignoreZeroBG))
            {
                $0.ignoreZeroBG = $1
            }

            // finally persist the whole struct
            Storage.shared.alarmConfiguration.value = cfg
        }

        migrateUrgentLowAlarm()
        migrateLowAlarm()
    }

    // MARK: - One-off alarm migrations

    /// Reads *all* `alertUrgentLow*` keys, converts them into a single `Alarm`,
    /// saves it to the modern `[Alarm]` store, then deletes the legacy keys.
    private func migrateUrgentLowAlarm() {
        // Did the user ever change that alert?  (No key ⇒ nothing to do.)
        guard UserDefaultsValue<Bool>(key: "alertUrgentLowActive", default: false).exists else { return }

        /// Helper: fetch-then-delete a legacy value in one line.
        func take<V: AnyConvertible & Equatable>(_ key: String, default def: V) -> V {
            let box = UserDefaultsValue<V>(key: key, default: def)
            defer { box.setNil(key: key) }
            return box.value
        }

        // Build the new Alarm ------------------------------------------------
        var alarm = Alarm(type: .low)
        alarm.name = "Urgent Low"
        alarm.isEnabled = take("alertUrgentLowActive", default: false)
        alarm.belowBG = Double(take("alertUrgentLowBG", default: 55.0))
        alarm.predictiveMinutes = take("alertUrgentLowPredictiveMinutes", default: 0)
        alarm.snoozeDuration = take("alertUrgentLowSnooze", default: 5)
        alarm.snoozedUntil = take("alertUrgentLowSnoozedTime", default: nil as Date?)
        alarm.soundFile = SoundFile(
            rawValue: take("alertUrgentLowSound",
                           default: "Emergency_Alarm_Siren"))
            ?? .emergencyAlarmSiren

        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertUrgentLowAudible",
                           default: "Always").lowercased()) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertUrgentLowRepeat",
                           default: "Always").lowercased()) ?? .always

        // Day / Night active-window (“Pre-Snooze”)
        let autoStr = take("alertUrgentLowAutosnooze", default: "Never").lowercased()
        let dayFlag = take("alertUrgentLowAutosnoozeDay", default: false)
        let nightFlag = take("alertUrgentLowAutosnoozeNight", default: false)

        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr {
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always // “Never” → always active
            }
        }()

        // Persist -----------------------------------------------------------------
        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: - Low-BG alarm -------------------------------------------------------

    private func migrateLowAlarm() {
        // Bail if the old keys were never written
        guard UserDefaultsValue<Bool>(key: "alertLowActive", default: false).exists else { return }

        // tiny helper: fetch value → erase key
        func take<V: AnyConvertible & Equatable>(_ key: String, default def: V) -> V {
            let box = UserDefaultsValue<V>(key: key, default: def)
            defer { box.setNil(key: key) }
            return box.value
        }

        // Build the new Alarm ----------------------------------------------------
        var alarm = Alarm(type: .low)
        alarm.name = "Low"
        alarm.isEnabled = take("alertLowActive", default: false)
        alarm.belowBG = Double(take("alertLowBG", default: 70.0))

        // “Persistent ≥ X min”  → `persistentMinutes`
        alarm.persistentMinutes = take("alertLowPersistent", default: 0)

        // “Persistence max BG drop” -- ignoring this for now
        // let persistentLowTriggerImmediatelyBG = UserDefaultsRepository.alertLowBG.value - UserDefaultsRepository.alertLowPersistenceMax.value
        // (Float(persistentLowBG) <= UserDefaultsRepository.alertLowBG.value || Float(currentBG) <= persistentLowTriggerImmediatelyBG)
        _ = Double(take("alertLowPersistenceMax", default: 5.0))

        alarm.snoozeDuration = take("alertLowSnooze", default: 5)
        alarm.snoozedUntil = take("alertLowSnoozedTime", default: nil as Date?)
        alarm.soundFile = SoundFile(
            rawValue: take("alertLowSound",
                           default: "Indeed")) ?? .indeed

        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertLowAudible",
                           default: "Always").lowercased()) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertLowRepeat",
                           default: "Always").lowercased()) ?? .always

        // activeOption  ← legacy “Pre-Snooze” flags / picker
        let autoStr = take("alertLowAutosnooze", default: "Never").lowercased()
        let dayFlag = take("alertLowAutosnoozeDay", default: false)
        let nightFlag = take("alertLowAutosnoozeNight", default: false)

        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr {
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always
            }
        }()

        // Done → append to the modern store
        Storage.shared.alarms.value.append(alarm)
    }
}
