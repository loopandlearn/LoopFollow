// LoopFollow
// Storage+Migrate.swift
// Created by Jonas Björkert.

import Foundation

extension Storage {
    func migrateStep2() {
        // Migrate from old system to new position-based system
        if remoteType.value != .none {
            remotePosition.value = .position2
            alarmsPosition.value = .more
        } else {
            alarmsPosition.value = .position2
            remotePosition.value = .more
        }
        nightscoutPosition.value = .position4
    }

    func migrateStep1() {
        Storage.shared.url.value = ObservableUserDefaults.shared.old_url.value
        Storage.shared.device.value = ObservableUserDefaults.shared.old_device.value
        Storage.shared.nsWriteAuth.value = ObservableUserDefaults.shared.old_nsWriteAuth.value
        Storage.shared.nsAdminAuth.value = ObservableUserDefaults.shared.old_nsAdminAuth.value

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

        move(UserDefaultsValue<Bool>(key: "persistentNotification", default: true), into: Storage.shared.persistentNotification)

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

        // ── Dexcom Share --------------------------------------------------------
        move(UserDefaultsValue<String>(key: "shareUserName", default: ""),
             into: Storage.shared.shareUserName)

        move(UserDefaultsValue<String>(key: "sharePassword", default: ""),
             into: Storage.shared.sharePassword)

        move(UserDefaultsValue<String>(key: "shareServer", default: "US"),
             into: Storage.shared.shareServer)

        // ── Graph ---------------------------------------------------------------
        moveFloatToDouble(
            UserDefaultsValue<Float>(key: "chartScaleX", default: 18.0),
            into: Storage.shared.chartScaleX
        )

        // ── Advanced settings ---------------------------------------------------
        move(UserDefaultsValue<Bool>(key: "downloadTreatments", default: true),
             into: Storage.shared.downloadTreatments)
        move(UserDefaultsValue<Bool>(key: "downloadPrediction", default: true),
             into: Storage.shared.downloadPrediction)
        move(UserDefaultsValue<Bool>(key: "graphOtherTreatments", default: true),
             into: Storage.shared.graphOtherTreatments)
        move(UserDefaultsValue<Bool>(key: "graphBasal", default: true),
             into: Storage.shared.graphBasal)
        move(UserDefaultsValue<Bool>(key: "graphBolus", default: true),
             into: Storage.shared.graphBolus)
        move(UserDefaultsValue<Bool>(key: "graphCarbs", default: true),
             into: Storage.shared.graphCarbs)
        move(UserDefaultsValue<Int>(key: "bgUpdateDelay", default: 10),
             into: Storage.shared.bgUpdateDelay)

        // ── Insert times --------------------------------------------------------
        move(UserDefaultsValue<TimeInterval>(key: "alertCageInsertTime", default: 0),
             into: Storage.shared.cageInsertTime)
        move(UserDefaultsValue<TimeInterval>(key: "alertSageInsertTime", default: 0),
             into: Storage.shared.sageInsertTime)

        // ── Version-cache / notification bookkeeping ---------------------------
        move(UserDefaultsValue<String?>(key: "cachedForVersion", default: nil),
             into: Storage.shared.cachedForVersion)
        move(UserDefaultsValue<String?>(key: "latestVersion", default: nil),
             into: Storage.shared.latestVersion)
        move(UserDefaultsValue<Date?>(key: "latestVersionChecked", default: nil),
             into: Storage.shared.latestVersionChecked)
        move(UserDefaultsValue<Bool>(key: "currentVersionBlackListed", default: false),
             into: Storage.shared.currentVersionBlackListed)
        move(UserDefaultsValue<Date?>(key: "lastBlacklistNotificationShown", default: nil),
             into: Storage.shared.lastBlacklistNotificationShown)
        move(UserDefaultsValue<Date?>(key: "lastVersionUpdateNotificationShown", default: nil),
             into: Storage.shared.lastVersionUpdateNotificationShown)
        move(UserDefaultsValue<Date?>(key: "lastExpirationNotificationShown", default: nil),
             into: Storage.shared.lastExpirationNotificationShown)

        move(UserDefaultsValue<Bool>(key: "hideInfoTable", default: false), into: Storage.shared.hideInfoTable)
        move(UserDefaultsValue<String>(key: "token", default: ""), into: Storage.shared.token)
        move(UserDefaultsValue<String>(key: "units", default: "mg/dL"), into: Storage.shared.units)

        move(UserDefaultsValue<[Int]>(key: "infoSort",
                                      default: InfoType.allCases.map { $0.sortOrder }),
             into: Storage.shared.infoSort)

        move(UserDefaultsValue<[Bool]>(key: "infoVisible",
                                       default: InfoType.allCases.map { $0.defaultVisible }),
             into: Storage.shared.infoVisible)

        migrateUrgentLowAlarm()
        migrateLowAlarm()
        migrateHighAlarm()
        migrateUrgentHighAlarm()
        migrateFastDropAlarm()
        migrateFastRiseAlarm()
        migrateMissedReadingAlarm()
        migrateNotLoopingAlarm()
        migrateMissedBolusAlarm()
        migrateSensorChangeAlarm()
        migratePumpChangeAlarm()
        migrateOverrideStartAlarm()
        migrateOverrideEndAlarm()
        migrateTempTargetStartAlarm()
        migrateTempTargetEndAlarm()
        migrateTemporaryBGAlarm()
        migratePumpVolumeAlarm()
        migrateIOBAlarm()
        migrateCOBAlarm()
        migrateBatteryAlarm()
        migrateBatteryDropAlarm()
        migrateRecBolusAlarm()
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

    // MARK: - High-BG alarm -----------------------------------------------------

    private func migrateHighAlarm() {
        // Only run if the legacy key ever existed
        guard UserDefaultsValue<Bool>(key: "alertHighActive", default: false).exists else { return }

        /// Fetch → erase helper
        func take<V: AnyConvertible & Equatable>(_ key: String, default def: V) -> V {
            let box = UserDefaultsValue<V>(key: key, default: def)
            defer { box.setNil(key: key) } // remove legacy value
            return box.value
        }

        // ---------- Build Alarm -----------------------------------------------
        var alarm = Alarm(type: .high)
        alarm.name = "High"
        alarm.isEnabled = take("alertHighActive", default: false)
        alarm.aboveBG = Double(take("alertHighBG", default: 180.0))

        alarm.persistentMinutes = take("alertHighPersistent", default: 60)
        alarm.snoozeDuration = take("alertHighSnooze", default: 60)
        alarm.snoozedUntil = take("alertHighSnoozedTime", default: nil as Date?)

        alarm.soundFile = SoundFile(
            rawValue: take("alertHighSound",
                           default: "Time_Has_Come")) ?? .timeHasCome

        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertHighAudible",
                           default: "Always").lowercased()) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertHighRepeat",
                           default: "Always").lowercased()) ?? .always

        // ── activeOption derived from “Pre-Snooze” picker & flags
        let autoStr = take("alertHighAutosnooze", default: "Never").lowercased()
        let dayFlag = take("alertHighAutosnoozeDay", default: false)
        let nightFlag = take("alertHighAutosnoozeNight", default: false)

        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr {
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always
            }
        }()

        // ---------- Persist & we’re done --------------------------------------
        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: - Urgent-High alarm --------------------------------------------------

    private func migrateUrgentHighAlarm() {
        // run only once, only if the user ever changed that toggle
        guard UserDefaultsValue<Bool>(key: "alertUrgentHighActive", default: false).exists else { return }

        // helper: read-then-erase a legacy value
        func take<V: AnyConvertible & Equatable>(_ key: String, default def: V) -> V {
            let box = UserDefaultsValue<V>(key: key, default: def)
            defer { box.setNil(key: key) } // wipe legacy key
            return box.value
        }

        // ───────── Build the Alarm ────────────────────────────────────────────
        var alarm = Alarm(type: .high) // we map to the existing `.high` type
        alarm.name = "Urgent High"
        alarm.isEnabled = take("alertUrgentHighActive", default: false)
        alarm.aboveBG = Double(take("alertUrgentHighBG", default: 250.0))

        alarm.snoozeDuration = take("alertUrgentHighSnooze", default: 30)
        alarm.snoozedUntil = take("alertUrgentHighSnoozedTime", default: nil as Date?)

        alarm.soundFile = SoundFile(
            rawValue: take("alertUrgentHighSound",
                           default: "Pager_Beeps")) ?? .pagerBeeps

        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertUrgentHighAudible",
                           default: "Always").lowercased()) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertUrgentHighRepeat",
                           default: "Always").lowercased()) ?? .always

        // activeOption comes from the old “Pre-Snooze” picker + its day/night flags
        let autoStr = take("alertUrgentHighAutosnooze", default: "Never").lowercased()
        let dayFlag = take("alertUrgentHighAutosnoozeDay", default: false)
        let nightFlag = take("alertUrgentHighAutosnoozeNight", default: false)

        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr { // fall back to picker value
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always
            }
        }()

        // ───────── Persist in new storage ─────────────────────────────────────
        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: - Fast-Drop alarm ----------------------------------------------------

    private func migrateFastDropAlarm() {
        guard UserDefaultsValue<Bool>(key: "alertFastDropDeltaActive",
                                      default: false).exists else { return }

        // helper: read-then-erase
        func take<V: AnyConvertible & Equatable>(_ k: String, default d: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: d)
            defer { box.setNil(key: k) }
            return box.value
        }

        var alarm = Alarm(type: .fastDrop)
        alarm.name = "Fast Drop"
        alarm.isEnabled = take("alertFastDropDeltaActive", default: false)

        // core trigger parameters
        alarm.delta = Double(take("alertFastDropDelta", default: 10.0))
        alarm.monitoringWindow = take("alertFastDropReadings", default: 3) - 1 // store #readings
        if take("alertFastDropUseLimit", default: false) {
            alarm.belowBG = Double(take("alertFastDropBelowBG", default: 120.0))
        }

        // snoozing
        alarm.snoozeDuration = take("alertFastDropDeltaSnooze", default: 10)
        alarm.snoozedUntil = take("alertFastDropSnoozedTime", default: nil as Date?)

        // sound + options
        alarm.soundFile = SoundFile(
            rawValue: take("alertFastDropSound", default: "Big_Clock_Ticking")
        ) ?? .bigClockTicking

        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertFastDropAudible", default: "Always").lowercased()
        ) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertFastDropRepeat", default: "Never").lowercased()
        ) ?? .never

        // activeOption from old “Pre-Snooze” picker + day/night flags
        let autoStr = take("alertFastDropAutosnooze", default: "Never").lowercased()
        let dayFlag = take("alertFastDropAutosnoozeDay", default: false)
        let nightFlag = take("alertFastDropAutosnoozeNight", default: false)
        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr {
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always
            }
        }()

        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: - Fast-Rise alarm ----------------------------------------------------

    private func migrateFastRiseAlarm() {
        guard UserDefaultsValue<Bool>(key: "alertFastRiseDeltaActive",
                                      default: false).exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, default d: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: d)
            defer { box.setNil(key: k) }
            return box.value
        }

        var alarm = Alarm(type: .fastRise)
        alarm.name = "Fast Rise"
        alarm.isEnabled = take("alertFastRiseDeltaActive", default: false)

        alarm.delta = Double(take("alertFastRiseDelta", default: 10.0))
        alarm.monitoringWindow = take("alertFastRiseReadings", default: 3)
        if take("alertFastRiseUseLimit", default: false) {
            alarm.aboveBG = Double(take("alertFastRiseAboveBG", default: 200.0))
        }

        alarm.snoozeDuration = take("alertFastRiseDeltaSnooze", default: 10)
        alarm.snoozedUntil = take("alertFastRiseSnoozedTime", default: nil as Date?)

        alarm.soundFile = SoundFile(
            rawValue: take("alertFastRiseSound",
                           default: "Cartoon_Fail_Strings_Trumpet")
        ) ?? .cartoonFailStringsTrumpet

        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertFastRiseAudible", default: "Always").lowercased()
        ) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertFastRiseRepeat", default: "Never").lowercased()
        ) ?? .never

        let autoStr = take("alertFastRiseAutosnooze", default: "Never").lowercased()
        let dayFlag = take("alertFastRiseAutosnoozeDay", default: false)
        let nightFlag = take("alertFastRiseAutosnoozeNight", default: false)
        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr {
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always
            }
        }()

        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: - Missed-Reading alarm ---------------------------------------------

    private func migrateMissedReadingAlarm() {
        // Run only when the user has ever modified those settings
        guard UserDefaultsValue<Bool>(key: "alertMissedReadingActive",
                                      default: false).exists else { return }

        // read-then-erase helper
        func take<V: AnyConvertible & Equatable>(_ k: String, default d: V) -> V {
            let b = UserDefaultsValue<V>(key: k, default: d)
            defer { b.setNil(key: k) }
            return b.value
        }

        var alarm = Alarm(type: .missedReading)
        alarm.name = "Missed Reading"
        alarm.isEnabled = take("alertMissedReadingActive", default: false)

        // “No CGM data for X minutes”
        alarm.threshold = take("alertMissedReading", default: 31)

        // snoozing
        alarm.snoozeDuration = take("alertMissedReadingSnooze", default: 30)
        alarm.snoozedUntil = take("alertMissedReadingSnoozedTime",
                                  default: nil as Date?)
        // (legacy “is-snoozed” flag is implicit in snoozedUntil)

        // sound
        alarm.soundFile = SoundFile(
            rawValue: take("alertMissedReadingSound",
                           default: "Cartoon_Tip_Toe_Sneaky_Walk")
        ) ?? .cartoonTipToeSneakyWalk

        // play / repeat options
        alarm.playSoundOption = PlaySoundOption(
            rawValue: take("alertMissedReadingAudible",
                           default: "Always").lowercased()
        ) ?? .always

        alarm.repeatSoundOption = RepeatSoundOption(
            rawValue: take("alertMissedReadingRepeat",
                           default: "Never").lowercased()
        ) ?? .never

        // activeOption ← “Pre-Snooze” picker + day/night flags
        let autoStr = take("alertMissedReadingAutosnooze", default: "Never")
            .lowercased()
        let dayFlag = take("alertMissedReadingAutosnoozeDay", default: false)
        let nightFlag = take("alertMissedReadingAutosnoozeNight", default: false)

        alarm.activeOption = {
            if dayFlag, !nightFlag { return .day }
            if !dayFlag, nightFlag { return .night }
            switch autoStr {
            case "day", "at day": return .day
            case "night", "at night": return .night
            default: return .always // “Never” → always on
            }
        }()

        // store in the new world
        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: - “Not Looping”  (legacy → Storage.shared.alarms)

    private func migrateNotLoopingAlarm() {
        // Check if the user ever configured this alarm
        let activeFlag = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: false)
        guard activeFlag.exists else { return } // nothing to migrate

        // Convenience: read-then-erase
        func take<V: AnyConvertible & Equatable>(_ key: String, default def: V) -> V {
            let box = UserDefaultsValue<V>(key: key, default: def)
            defer { box.setNil(key: key) } // wipe after reading
            return box.value
        }

        // Build the new Alarm ---------------------------------------------------
        var alarm = Alarm(type: .notLooping)
        alarm.name = "Not Looping Alert"
        alarm.isEnabled = take("alertNotLoopingActive", default: false)
        alarm.threshold = Double(take("alertNotLooping", default: 31)) // minutes
        alarm.snoozeDuration = take("alertNotLoopingSnooze", default: 30)
        alarm.snoozedUntil = take("alertNotLoopingSnoozedTime", default: nil as Date?)
        alarm.soundFile = SoundFile(rawValue:
            take("alertNotLoopingSound",
                 default: "Sci-Fi_Engine_Shut_Down")) ?? .sciFiEngineShutDown

        // ── ACTIVE-DURING (day/night)  ← old **Pre-Snooze** flags --------------
        let actDay = take("alertNotLoopingAutosnoozeDay", default: false)
        let actNight = take("alertNotLoopingAutosnoozeNight", default: false)
        alarm.activeOption = {
            switch (actDay, actNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always // “Never” in old UI
            }
        }()

        // ── PLAY-SOUND option ---------------------------------------------------
        let playStr = take("alertNotLoopingAudible", default: "Always").lowercased()
        let playDay = take("alertNotLoopingDayTimeAudible", default: true)
        let playNight = take("alertNotLoopingNightTimeAudible", default: true)
        alarm.playSoundOption = {
            if !playDay, !playNight { return .never }
            else if playDay, playNight { return .always }
            else if playDay { return .day }
            else { return .night }
        }()

        // ── REPEAT-SOUND option -------------------------------------------------
        let repStr = take("alertNotLoopingRepeat", default: "Never").lowercased()
        let repDay = take("alertNotLoopingDayTime", default: false)
        let repNight = take("alertNotLoopingNightTime", default: false)
        alarm.repeatSoundOption = {
            if repDay, repNight { return .always }
            else if repDay, !repNight { return .day }
            else if repNight, !repDay { return .night }
            else { return .never }
        }()

        // ── BG-limit guard ------------------------------------------------------
        if take("alertNotLoopingUseLimits", default: false) {
            alarm.belowBG = Double(take("alertNotLoopingLowerLimit", default: 100.0))
            alarm.aboveBG = Double(take("alertNotLoopingUpperLimit", default: 160.0))
        }

        // ── Per-alarm snooze state ---------------------------------------------
        if !take("alertNotLoopingIsSnoozed", default: false) {
            alarm.snoozedUntil = nil // ignore stored date if flag isn’t set
        }

        // Persist & finish -------------------------------------------------------
        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // MARK: – Missed-Bolus alarm -------------------------------------------------

    private func migrateMissedBolusAlarm() {
        // Was the old alarm ever configured?
        let legacyActive = UserDefaultsValue<Bool>(key: "alertMissedBolusActive",
                                                   default: false)
        guard legacyActive.exists else { return } // nothing to do

        // helper: read-then-delete ------------------------------------------------
        func take<V: AnyConvertible & Equatable>(_ k: String,
                                                 _ def: V) -> V
        {
            let box = UserDefaultsValue<V>(key: k, default: def)
            defer { box.setNil(key: k) } // wipe after reading
            return box.value
        }

        // ────────────────────────────────────────────────────────────────────────
        // Build the new Alarm
        // ────────────────────────────────────────────────────────────────────────
        var alarm = Alarm(type: .missedBolus)
        alarm.name = "Missed Bolus Alert"
        alarm.isEnabled = take("alertMissedBolusActive", false)

        // core timings
        alarm.monitoringWindow = take("alertMissedBolus", 10) // delay
        alarm.predictiveMinutes = take("alertMissedBolusPrebolus", 20) // pre-bolus window
        alarm.snoozeDuration = take("alertMissedBolusSnooze", 10)

        // snooze-state
        if take("alertMissedBolusIsSnoozed", false) {
            alarm.snoozedUntil = take("alertMissedBolusSnoozedTime",
                                      nil as Date?)
        }

        // carb / bolus filters
        alarm.delta = take("alertMissedBolusIgnoreBolus", 0.5)
        alarm.threshold = Double(
            take("alertMissedBolusLowGrams", 10))
        alarm.aboveBG = Double(
            take("alertMissedBolusLowGramsBG", 70.0))

        // sound & tone
        alarm.soundFile = SoundFile(rawValue:
            take("alertMissedBolusSound",
                 "Dhol_Shuffleloop")) ?? .dholShuffleloop

        // ── ACTIVE-DURING  ← old “Pre-Snooze” flags
        let actDay = take("alertMissedBolusAutosnoozeDay", false)
        let actNight = take("alertMissedBolusAutosnoozeNight", false)
        alarm.activeOption = {
            switch (actDay, actNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always // “Never” → always
            }
        }()

        // ── PLAY-SOUND  ← old “PlaySound” picker
        let playDay = take("alertMissedBolusDayTimeAudible", true)
        let playNight = take("alertMissedBolusNightTimeAudible", true)
        alarm.playSoundOption = {
            switch (playDay, playNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // ── REPEAT-SOUND  ← old “Repeat Sound” picker
        let repDay = take("alertMissedBolusDayTime", false)
        let repNight = take("alertMissedBolusNightTime", false)
        alarm.repeatSoundOption = {
            switch (repDay, repNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // (The deprecated “alertMissedBolusQuiet” key is ignored.)

        // ── Store & finish ------------------------------------------------------
        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // ─────────────────────────────────────────────────────────────────────────────

    //  MARK: SAGE  →  .sensorChange

    // ─────────────────────────────────────────────────────────────────────────────
    private func migrateSensorChangeAlarm() {
        // Was the old setting ever stored?
        let flag = UserDefaultsValue<Bool>(key: "alertSAGEActive", default: false)
        guard flag.exists else { return }

        // tiny helper that *reads + wipes* a legacy key
        func take<V: AnyConvertible & Equatable>(_ k: String, _ def: V) -> V {
            let b = UserDefaultsValue<V>(key: k, default: def)
            defer { b.setNil(key: k) }
            return b.value
        }

        var alarm = Alarm(type: .sensorChange)
        alarm.name = "Sensor Change Reminder"
        alarm.isEnabled = take("alertSAGEActive", false)
        alarm.threshold = Double(take("alertSAGE", 8)) // hours
        alarm.snoozeDuration = take("alertSAGESnooze", 2) // hours
        if take("alertSAGEIsSnoozed", false) {
            alarm.snoozedUntil = take("alertSAGESnoozedTime", nil as Date?)
        }
        alarm.soundFile = SoundFile(rawValue:
            take("alertSAGESound", "Wake_Up_Will_You")) ?? .wakeUpWillYou

        // ACTIVE (day / night)
        let actDay = take("alertSAGEAutosnoozeDay", false)
        let actNight = take("alertSAGEAutosnoozeNight", true)
        alarm.activeOption = {
            switch (actDay, actNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always
            }
        }()

        // PLAY sound
        let playDay = take("alertSAGEDayTimeAudible", true)
        let playNight = take("alertSAGENightTimeAudible", true)
        alarm.playSoundOption = {
            switch (playDay, playNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // REPEAT sound
        let repDay = take("alertSAGEDayTime", false)
        let repNight = take("alertSAGENightTime", false)
        alarm.repeatSoundOption = {
            switch (repDay, repNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // Persist
        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // ─────────────────────────────────────────────────────────────────────────────

    //  MARK: CAGE  →  .pumpChange

    // ─────────────────────────────────────────────────────────────────────────────
    private func migratePumpChangeAlarm() {
        let flag = UserDefaultsValue<Bool>(key: "alertCAGEActive", default: false)
        guard flag.exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, _ def: V) -> V {
            let b = UserDefaultsValue<V>(key: k, default: def)
            defer { b.setNil(key: k) }
            return b.value
        }

        var alarm = Alarm(type: .pumpChange)
        alarm.name = "Pump / Cannula Change"
        alarm.isEnabled = take("alertCAGEActive", false)
        alarm.threshold = Double(take("alertCAGE", 4)) // hours
        alarm.snoozeDuration = take("alertCAGESnooze", 2) // hours
        if take("alertCAGEIsSnoozed", false) {
            alarm.snoozedUntil = take("alertCAGESnoozedTime", nil as Date?)
        }
        alarm.soundFile = SoundFile(rawValue:
            take("alertCAGESound", "Wake_Up_Will_You")) ?? .wakeUpWillYou

        // ACTIVE
        let actDay = take("alertCAGEAutosnoozeDay", false)
        let actNight = take("alertCAGEAutosnoozeNight", true)
        alarm.activeOption = {
            switch (actDay, actNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always
            }
        }()

        // PLAY
        let playDay = take("alertCAGEDayTimeAudible", true)
        let playNight = take("alertCAGENightTimeAudible", true)
        alarm.playSoundOption = {
            switch (playDay, playNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // REPEAT
        let repDay = take("alertCAGEDayTime", false)
        let repNight = take("alertCAGENightTime", false)
        alarm.repeatSoundOption = {
            switch (repDay, repNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // ─────────────────────────────────────────────────────────────────────────────

    //  MARK: Override-Start  →  .overrideStart

    // ─────────────────────────────────────────────────────────────────────────────
    private func migrateOverrideStartAlarm() {
        let exists = UserDefaultsValue<Bool>(key: "alertOverrideStart", default: false)
        guard exists.exists else { return } // user never touched it

        func take<V: AnyConvertible & Equatable>(_ k: String, _ def: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: def)
            defer { box.setNil(key: k) } // wipe after reading
            return box.value
        }

        var alarm = Alarm(type: .overrideStart)
        alarm.name = "Override Started"

        alarm.isEnabled = take("alertOverrideStart", false)
        alarm.snoozeDuration = 5 // legacy UI had no stepper
        if take("alertOverrideStartIsSnoozed", false) {
            alarm.snoozedUntil = take("alertOverrideStartSnoozedTime", nil as Date?)
        }

        alarm.soundFile = SoundFile(
            rawValue: take("alertOverrideStartSound", "Ending_Reached")
        ) ?? .endingReached

        // ── ACTIVE (legacy “Pre-Snooze” day/night flags) ──────────────
        let actDay = take("alertOverrideStartAutosnoozeDay", false)
        let actNight = take("alertOverrideStartAutosnoozeNight", false)
        alarm.activeOption = {
            switch (actDay, actNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always
            }
        }()

        // ── PLAY (legacy “Play Sound” day/night flags) ───────────────
        let playDay = take("alertOverrideStartDayTimeAudible", true)
        let playNight = take("alertOverrideStartNightTimeAudible", true)
        alarm.playSoundOption = {
            switch (playDay, playNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // ── REPEAT (legacy “Repeat Sound” day/night flags) ───────────
        let repDay = take("alertOverrideStartDayTime", false)
        let repNight = take("alertOverrideStartNightTime", false)
        alarm.repeatSoundOption = {
            switch (repDay, repNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // ignore & wipe unused keys
        _ = take("alertOverrideStartQuiet", false as Bool)
        _ = take("alertOverrideStartRepeatAudible", "Always" as String)

        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // ─────────────────────────────────────────────────────────────────────────────

    //  MARK: Override-End  →  .overrideEnd

    // ─────────────────────────────────────────────────────────────────────────────
    private func migrateOverrideEndAlarm() {
        let exists = UserDefaultsValue<Bool>(key: "alertOverrideEnd", default: false)
        guard exists.exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, _ def: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: def)
            defer { box.setNil(key: k) }
            return box.value
        }

        var alarm = Alarm(type: .overrideEnd)
        alarm.name = "Override Ended"

        alarm.isEnabled = take("alertOverrideEnd", false)
        alarm.snoozeDuration = 5
        if take("alertOverrideEndIsSnoozed", false) {
            alarm.snoozedUntil = take("alertOverrideEndSnoozedTime", nil as Date?)
        }

        alarm.soundFile = SoundFile(
            rawValue: take("alertOverrideEndSound", "Alert_Tone_Busy")
        ) ?? .alertToneBusy

        // ACTIVE
        let actDay = take("alertOverrideEndAutosnoozeDay", false)
        let actNight = take("alertOverrideEndAutosnoozeNight", false)
        alarm.activeOption = {
            switch (actDay, actNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always
            }
        }()

        // PLAY
        let playDay = take("alertOverrideEndDayTimeAudible", true)
        let playNight = take("alertOverrideEndNightTimeAudible", true)
        alarm.playSoundOption = {
            switch (playDay, playNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // REPEAT
        let repDay = take("alertOverrideEndDayTime", false)
        let repNight = take("alertOverrideEndNightTime", false)
        alarm.repeatSoundOption = {
            switch (repDay, repNight) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // wipe unused keys
        _ = take("alertOverrideEndQuiet", false as Bool)
        _ = take("alertOverrideEndRepeatAudible", "Always" as String)

        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // MARK: ––––– Temp-Target START  →  .tempTargetStart –––––

    private func migrateTempTargetStartAlarm() {
        let touched = UserDefaultsValue<Bool>(key: "alertTempTargetStart", default: false)
        guard touched.exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, _ def: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: def)
            defer { box.setNil(key: k) } // scrub after read
            return box.value
        }

        var alarm = Alarm(type: .tempTargetStart)
        alarm.name = "Temp Target Started"

        alarm.isEnabled = take("alertTempTargetStart", false)
        alarm.snoozeDuration = 5
        if take("alertTempTargetStartIsSnoozed", false) {
            alarm.snoozedUntil = take("alertTempTargetStartSnoozedTime", nil as Date?)
        }

        alarm.soundFile = SoundFile(
            rawValue: take("alertTempTargetStartSound", "Ending_Reached")
        ) ?? .endingReached

        // ACTIVE  ← legacy Pre-Snooze day/night flags
        alarm.activeOption = {
            let d = take("alertTempTargetStartAutosnoozeDay", false)
            let n = take("alertTempTargetStartAutosnoozeNight", false)
            switch (d, n) { case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always }
        }()

        // PLAY
        alarm.playSoundOption = {
            let d = take("alertTempTargetStartDayTimeAudible", true)
            let n = take("alertTempTargetStartNightTimeAudible", true)
            switch (d, n) { case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never }
        }()

        // REPEAT
        alarm.repeatSoundOption = {
            let d = take("alertTempTargetStartDayTime", false)
            let n = take("alertTempTargetStartNightTime", false)
            switch (d, n) { case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never }
        }()

        // wipe “quiet / RepeatAudible” extras
        _ = take("alertTempTargetStartQuiet", false as Bool)
        _ = take("alertTempTargetStartRepeatAudible", "Always" as String)

        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // MARK: ––––– Temp-Target END  →  .tempTargetEnd –––––

    private func migrateTempTargetEndAlarm() {
        let touched = UserDefaultsValue<Bool>(key: "alertTempTargetEnd", default: false)
        guard touched.exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, _ def: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: def)
            defer { box.setNil(key: k) }
            return box.value
        }

        var alarm = Alarm(type: .tempTargetEnd)
        alarm.name = "Temp Target Ended"

        alarm.isEnabled = take("alertTempTargetEnd", false)
        alarm.snoozeDuration = 5
        if take("alertTempTargetEndIsSnoozed", false) {
            alarm.snoozedUntil = take("alertTempTargetEndSnoozedTime", nil as Date?)
        }

        alarm.soundFile = SoundFile(
            rawValue: take("alertTempTargetEndSound", "Alert_Tone_Busy")
        ) ?? .alertToneBusy

        alarm.activeOption = {
            let d = take("alertTempTargetEndAutosnoozeDay", false)
            let n = take("alertTempTargetEndAutosnoozeNight", false)
            switch (d, n) { case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always }
        }()

        alarm.playSoundOption = {
            let d = take("alertTempTargetEndDayTimeAudible", true)
            let n = take("alertTempTargetEndNightTimeAudible", true)
            switch (d, n) { case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never }
        }()

        alarm.repeatSoundOption = {
            let d = take("alertTempTargetEndDayTime", false)
            let n = take("alertTempTargetEndNightTime", false)
            switch (d, n) { case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never }
        }()

        _ = take("alertTempTargetEndQuiet", false as Bool)
        _ = take("alertTempTargetEndRepeatAudible", "Always" as String)

        var list = Storage.shared.alarms.value
        list.append(alarm)
        Storage.shared.alarms.value = list
    }

    // MARK: ––––– TEMPORARY BG LIMIT  →  .temporary –––––

    private func migrateTemporaryBGAlarm() {
        let flag = UserDefaultsValue<Bool>(key: "alertTemporaryActive", default: false)
        guard flag.exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, _ d: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: d)
            defer { box.setNil(key: k) }
            return box.value
        }

        var alarm = Alarm(type: .temporary)
        alarm.name = "Temporary BG Limit"
        alarm.isEnabled = take("alertTemporaryActive", false)

        // limit direction ↓ / ↑
        let limit = Double(take("alertTemporaryBG", 90.0 as Float))
        if take("alertTemporaryBelow", true) {
            alarm.belowBG = limit
        } else {
            alarm.aboveBG = limit
        }

        // audio & repeat
        alarm.soundFile = SoundFile(rawValue:
            take("alertTemporarySound", "Indeed")) ?? .indeed

        alarm.playSoundOption = take("alertTemporaryBGAudible", true) ? .always : .never
        alarm.repeatSoundOption = take("alertTemporaryBGRepeat", false) ? .always : .never

        Storage.shared.alarms.value.append(alarm)
    }

    // MARK: ––––– PUMP RESERVOIR LEVEL  →  .pump –––––

    private func migratePumpVolumeAlarm() {
        let flag = UserDefaultsValue<Bool>(key: "alertPump", default: false)
        guard flag.exists else { return }

        func take<V: AnyConvertible & Equatable>(_ k: String, _ d: V) -> V {
            let box = UserDefaultsValue<V>(key: k, default: d)
            defer { box.setNil(key: k) }
            return box.value
        }

        var alarm = Alarm(type: .pump)
        alarm.name = "Pump Reservoir"
        alarm.isEnabled = take("alertPump", false)
        alarm.threshold = Double(take("alertPumpAt", 10)) // units left

        // Snooze — stored in hours, so keep as-is.
        alarm.snoozeDuration = take("alertPumpSnoozeHours", 5)

        if take("alertPumpIsSnoozed", false) {
            alarm.snoozedUntil = take("alertPumpSnoozedTime", nil as Date?)
        }

        alarm.soundFile = SoundFile(rawValue:
            take("alertPumpSound", "Marimba_Descend")) ?? .marimbaDescend

        // PLAY-sound option (day / night / never)
        alarm.playSoundOption = {
            let d = take("alertPumpDayTimeAudible", true)
            let n = take("alertPumpNightTimeAudible", true)
            switch (d, n) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // REPEAT-sound option  – derived from legacy picker flags
        alarm.repeatSoundOption = {
            let d = take("alertPumpDayTime", false)
            let n = take("alertPumpNightTime", false)
            switch (d, n) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .never
            }
        }()

        // ACTIVE day/night  ← old “Pre-Snooze” flags
        alarm.activeOption = {
            let d = take("alertPumpAutosnoozeDay", false)
            let n = take("alertPumpAutosnoozeNight", false)
            switch (d, n) {
            case (true, true): return .always
            case (true, false): return .day
            case (false, true): return .night
            default: return .always
            }
        }()

        // Discard no-longer-needed extras
        _ = take("alertPumpQuiet", false as Bool)
        _ = take("alertPumpRepeat", "Never" as String)
        _ = take("alertPumpAudible", "Always" as String)
        _ = take("alertPumpAutosnooze", "Never" as String)

        Storage.shared.alarms.value.append(alarm)
    }

    // -----------------------------------------------------------------------------

    // MARK: - Helpers (place them once, near the top of the migrate() file)

    // -----------------------------------------------------------------------------

    /// Legacy picker + day/night flags  →  PlaySoundOption
    private func playOption(from picker: String,
                            dayFlag: Bool,
                            nightFlag: Bool) -> PlaySoundOption
    {
        let p = picker.lowercased()
        if p == "never" { return .never }
        if p == "always" { return .always }

        switch (dayFlag, nightFlag) {
        case (true, true): return .always
        case (true, false): return .day
        case (false, true): return .night
        default: return .never
        }
    }

    /// Legacy picker + day/night flags  →  RepeatSoundOption
    private func repeatOption(from picker: String,
                              dayFlag: Bool,
                              nightFlag: Bool) -> RepeatSoundOption
    {
        let p = picker.lowercased()
        if p == "never" { return .never }
        if p == "always" { return .always }

        switch (dayFlag, nightFlag) {
        case (true, true): return .always
        case (true, false): return .day
        case (false, true): return .night
        default: return .never
        }
    }

    /// Convenience: load-then-erase a legacy `UserDefaultsValue`
    private func take<V: AnyConvertible & Equatable>(
        _ key: String,
        _ defaultValue: V
    ) -> V {
        let box = UserDefaultsValue<V>(key: key, default: defaultValue)
        defer { box.setNil(key: key) }
        return box.value
    }

    // -----------------------------------------------------------------------------

    // MARK: - IOB Alarm migration

    // -----------------------------------------------------------------------------

    private func migrateIOBAlarm() {
        // Only migrate if the user ever touched IOB alarm settings
        guard UserDefaultsValue<Bool>(key: "alertIOB", default: false).exists else {
            return
        }

        var alarm = Alarm(type: .iob)
        alarm.name = "High IOB"
        alarm.isEnabled = take("alertIOB", false)
        alarm.aboveBG = nil // BG band not used
        alarm.threshold = Double(take("alertIOBAt", 1.5)) // units threshold
        alarm.bolusCountThreshold = take("alertIOBNumber", 3)
        alarm.bolusWindowMinutes = take("alertIOBBolusesWithin", 60)
        alarm.delta = Double(take("alertIOBMaxBoluses", 10)) // max total bolus
        alarm.snoozeDuration = take("alertIOBSnoozeHours", 1) * 60 // hours → minutes
        alarm.snoozedUntil = take("alertIOBSnoozedTime", nil as Date?)
        alarm.soundFile = SoundFile(rawValue:
            take("alertIOBSound", "Alert_Tone_Ringtone_1"))
            ?? .alertToneRingtone1

        // Audio options
        alarm.playSoundOption = playOption(
            from: take("alertIOBAudible", "Always"),
            dayFlag: take("alertIOBDayTimeAudible", true),
            nightFlag: take("alertIOBNightTimeAudible", true)
        )
        alarm.repeatSoundOption = repeatOption(
            from: take("alertIOBRepeat", "Always"),
            dayFlag: take("alertIOBDayTime", true),
            nightFlag: take("alertIOBNightTime", true)
        )

        // Active (day/night) option comes from the legacy “Pre-Snooze” picker,
        // but the IOB alarm never had one, so treat it as always-on.
        alarm.activeOption = .always

        // Persist
        Storage.shared.alarms.value.append(alarm)
    }

    // -----------------------------------------------------------------------------

    // MARK: - COB Alarm migration

    // -----------------------------------------------------------------------------

    private func migrateCOBAlarm() {
        // Only migrate if the user ever touched COB alarm settings
        guard UserDefaultsValue<Bool>(key: "alertCOB", default: false).exists else {
            return
        }

        var alarm = Alarm(type: .cob)
        alarm.name = "High COB"
        alarm.isEnabled = take("alertCOB", false)
        alarm.threshold = Double(take("alertCOBAt", 50)) // grams threshold
        alarm.snoozeDuration = take("alertCOBSnoozeHours", 1) * 60 // hours → minutes
        alarm.snoozedUntil = take("alertCOBSnoozedTime", nil as Date?)
        alarm.soundFile = SoundFile(rawValue:
            take("alertCOBSound", "Alert_Tone_Ringtone_2"))
            ?? .alertToneRingtone2

        // Audio options
        alarm.playSoundOption = playOption(
            from: take("alertCOBAudible", "Always"),
            dayFlag: take("alertCOBDayTimeAudible", true),
            nightFlag: take("alertCOBNightTimeAudible", true)
        )
        alarm.repeatSoundOption = repeatOption(
            from: take("alertCOBRepeat", "Always"),
            dayFlag: take("alertCOBDayTime", true),
            nightFlag: take("alertCOBNightTime", true)
        )

        alarm.activeOption = .always // same reason as above

        // Persist
        Storage.shared.alarms.value.append(alarm)
    }

    // =============================================================================
    //  BATTERY-LEVEL alarm  (old keys → .battery)
    // =============================================================================
    private func migrateBatteryAlarm() {
        guard UserDefaultsValue<Bool>(key: "alertBatteryActive",
                                      default: false).exists else { return }

        var alarm = Alarm(type: .battery)
        alarm.name = "Low Battery"
        alarm.isEnabled = take("alertBatteryActive", false)
        alarm.threshold = Double(take("alertBatteryLevel", 25)) // %
        alarm.snoozeDuration = take("alertBatterySnoozeHours", 1) * 60
        alarm.snoozedUntil = take("alertBatterySnoozedTime", nil as Date?)
        alarm.soundFile = SoundFile(rawValue:
            take("alertBatterySound", "Machine_Charge"))
            ?? .machineCharge

        // ── audio – legacy had a simple Bool “repeat / no-repeat”
        let rpt = take("alertBatteryRepeat", true)
        alarm.playSoundOption = .always // no day/night picker in legacy UI
        alarm.repeatSoundOption = rpt ? .always : .never

        alarm.activeOption = .always // no day/night activation picker
        Storage.shared.alarms.value.append(alarm)
    }

    // =============================================================================
    //  BATTERY-DROP alarm  (old keys → .batteryDrop)
    // =============================================================================
    private func migrateBatteryDropAlarm() {
        guard UserDefaultsValue<Bool>(key: "alertBatteryDropActive",
                                      default: false).exists else { return }

        var alarm = Alarm(type: .batteryDrop)
        alarm.name = "Battery Drop"
        alarm.isEnabled = take("alertBatteryDropActive", false)
        alarm.delta = Double(take("alertBatteryDropPercentage", 5)) // % drop
        alarm.monitoringWindow = take("alertBatteryDropPeriod", 15) // min
        alarm.snoozeDuration = take("alertBatteryDropSnoozeHours", 1) * 60
        alarm.snoozedUntil = take("alertBatteryDropSnoozedTime", nil as Date?)
        alarm.soundFile = SoundFile(rawValue:
            take("alertBatteryDropSound", "Machine_Charge"))
            ?? .machineCharge

        let rpt = take("alertBatteryDropRepeat", true)
        alarm.playSoundOption = .always
        alarm.repeatSoundOption = rpt ? .always : .never
        alarm.activeOption = .always

        Storage.shared.alarms.value.append(alarm)
    }

    // =============================================================================
    //  REC-BOLUS alarm  (old keys → .recBolus)
    // =============================================================================
    private func migrateRecBolusAlarm() {
        guard UserDefaultsValue<Bool>(key: "alertRecBolusActive",
                                      default: false).exists else { return }

        var alarm = Alarm(type: .recBolus)
        alarm.name = "Recommended Bolus"
        alarm.isEnabled = take("alertRecBolusActive", false)
        alarm.delta = take("alertRecBolusLevel", 1.0) // units
        alarm.snoozeDuration = take("alertRecBolusSnooze", 5) // min
        alarm.snoozedUntil = take("alertRecBolusSnoozedTime", nil as Date?)
        alarm.soundFile = SoundFile(rawValue:
            take("alertRecBolusSound", "Dhol_Shuffleloop"))
            ?? .dholShuffleloop

        let rpt = take("alertRecBolusRepeat", false)
        alarm.playSoundOption = .always
        alarm.repeatSoundOption = rpt ? .always : .never
        alarm.activeOption = .always

        Storage.shared.alarms.value.append(alarm)
    }
}
