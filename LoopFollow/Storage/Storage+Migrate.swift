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
    }
}
