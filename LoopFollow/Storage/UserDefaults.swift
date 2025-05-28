// LoopFollow
// UserDefaults.swift
// Created by Jon Fawcett on 2020-06-05.

import Foundation
import HealthKit
import UIKit

/*
 Legacy storage, we are moving away from this
 */

class UserDefaultsRepository {
    static let infoSort = UserDefaultsValue<[Int]>(key: "infoSort", default: InfoType.allCases.map { $0.sortOrder })
    static let infoVisible = UserDefaultsValue<[Bool]>(key: "infoVisible", default: InfoType.allCases.map { $0.defaultVisible })

    static func synchronizeInfoTypes() {
        var sortArray = infoSort.value
        var visibleArray = infoVisible.value

        // Current valid indices based on InfoType
        let currentValidIndices = InfoType.allCases.map { $0.rawValue }

        // Add missing indices to sortArray
        for index in currentValidIndices {
            if !sortArray.contains(index) {
                sortArray.append(index)
                // print("Added missing index \(index) to sortArray")
            }
        }

        // Remove deprecated indices
        sortArray = sortArray.filter { currentValidIndices.contains($0) }

        // Ensure visibleArray is updated with new entries
        if visibleArray.count < currentValidIndices.count {
            for i in visibleArray.count ..< currentValidIndices.count {
                visibleArray.append(InfoType(rawValue: i)?.defaultVisible ?? false)
                // print("Added default visibility for new index \(i)")
            }
        }

        // Trim excess elements if there are more than needed
        if visibleArray.count > currentValidIndices.count {
            visibleArray = Array(visibleArray.prefix(currentValidIndices.count))
            // print("Trimmed visibleArray to match current valid indices")
        }

        infoSort.value = sortArray
        infoVisible.value = visibleArray
    }

    static let hideInfoTable = UserDefaultsValue<Bool>(key: "hideInfoTable", default: false)

    // Nightscout Settings
    static let token = UserDefaultsValue<String>(key: "token", default: "")
    static let units = UserDefaultsValue<String>(key: "units", default: "mg/dL")

    static func getPreferredUnit() -> HKUnit {
        let unitString = units.value
        switch unitString {
        case "mmol/L":
            return .millimolesPerLiter
        default:
            return .milligramsPerDeciliter
        }
    }

    static func setPreferredUnit(_ unit: HKUnit) {
        var unitString = "mg/dL"
        if unit == .millimolesPerLiter {
            unitString = "mmol/L"
        }
        units.value = unitString
    }

    // Dexcom Share Settings
    static let shareUserName = UserDefaultsValue<String>(key: "shareUserName", default: "")
    static let sharePassword = UserDefaultsValue<String>(key: "sharePassword", default: "")
    static let shareServer = UserDefaultsValue<String>(key: "shareServer", default: "US")

    // Graph Settings
    static let chartScaleX = UserDefaultsValue<Float>(key: "chartScaleX", default: 18.0)

    // Deprecated, used to detect if backgroundRefresh was set to off. TODO: Remove in the beginning of 2026
    static let backgroundRefresh = UserDefaultsValue<Bool>(key: "backgroundRefresh", default: true)

    // Advanced Settings
    static let downloadTreatments = UserDefaultsValue<Bool>(key: "downloadTreatments", default: true)
    static let downloadPrediction = UserDefaultsValue<Bool>(key: "downloadPrediction", default: true)
    static let graphOtherTreatments = UserDefaultsValue<Bool>(key: "graphOtherTreatments", default: true)
    static let graphBasal = UserDefaultsValue<Bool>(key: "graphBasal", default: true)
    static let graphBolus = UserDefaultsValue<Bool>(key: "graphBolus", default: true)
    static let graphCarbs = UserDefaultsValue<Bool>(key: "graphCarbs", default: true)
    static let bgUpdateDelay = UserDefaultsValue<Int>(key: "bgUpdateDelay", default: 10)

    static let alertCageInsertTime = UserDefaultsValue<TimeInterval>(key: "alertCageInsertTime", default: 0)
    static let alertSageInsertTime = UserDefaultsValue<TimeInterval>(key: "alertSageInsertTime", default: 0)



    static let alertNotLoopingActive = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: false)
    static let alertNotLooping = UserDefaultsValue<Int>(key: "alertNotLooping", default: 31)
    static let alertNotLoopingSnooze = UserDefaultsValue<Int>(key: "alertNotLoopingSnooze", default: 30)
    static let alertNotLoopingUseLimits = UserDefaultsValue<Bool>(key: "alertNotLoopingUseLimits", default: false)
    static let alertNotLoopingLowerLimit = UserDefaultsValue<Float>(key: "alertNotLoopingBelowBG", default: 100.0)
    static let alertNotLoopingUpperLimit = UserDefaultsValue<Float>(key: "alertNotLoopingAboveBG", default: 160.0)
    static let alertNotLoopingSnoozedTime = UserDefaultsValue<Date?>(key: "alertNotLoopingSnoozedTime", default: nil)
    static let alertNotLoopingIsSnoozed = UserDefaultsValue<Bool>(key: "alertNotLoopingIsSnoozed", default: false)
    static let alertNotLoopingRepeat = UserDefaultsValue<String>(key: "alertNotLoopingRepeat", default: "Never")
    static let alertNotLoopingDayTime = UserDefaultsValue<Bool>(key: "alertNotLoopingDayTime", default: false)
    static let alertNotLoopingNightTime = UserDefaultsValue<Bool>(key: "alertNotLoopingNightTime", default: false)
    static let alertNotLoopingSound = UserDefaultsValue<String>(key: "alertNotLoopingSound", default: "Sci-Fi_Engine_Shut_Down")
    static let alertLastLoopTime = UserDefaultsValue<TimeInterval>(key: "alertLastLoopTime", default: 0)
    static let alertNotLoopingAudible = UserDefaultsValue<String>(key: "alertNotLoopingAudible", default: "Always")
    static let alertNotLoopingDayTimeAudible = UserDefaultsValue<Bool>(key: "alertNotLoopingDayTimeAudible", default: true)
    static let alertNotLoopingNightTimeAudible = UserDefaultsValue<Bool>(key: "alertNotLoopingNightTimeAudible", default: true)
    static let alertNotLoopingAutosnooze = UserDefaultsValue<String>(key: "alertNotLoopingAutosnooze", default: "Never")
    static let alertNotLoopingAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertNotLoopingAutosnoozeDay", default: false)
    static let alertNotLoopingAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertNotLoopingAutosnoozeNight", default: false)

    static let alertMissedBolusActive = UserDefaultsValue<Bool>(key: "alertMissedBolusActive", default: false)
    static let alertMissedBolus = UserDefaultsValue<Int>(key: "alertMissedBolus", default: 10)
    static let alertMissedBolusSnooze = UserDefaultsValue<Int>(key: "alertMissedBolusSnooze", default: 10)
    static let alertMissedBolusPrebolus = UserDefaultsValue<Int>(key: "alertMissedBolusPrebolus", default: 20)
    static let alertMissedBolusIgnoreBolus = UserDefaultsValue<Double>(key: "alertMissedBolusIgnoreBolus", default: 0.5)
    static let alertMissedBolusLowGrams = UserDefaultsValue<Int>(key: "alertMissedBolusLowGrams", default: 10)
    static let alertMissedBolusLowGramsBG = UserDefaultsValue<Float>(key: "alertMissedBolusLowGramsBG", default: 70.0)
    static let alertMissedBolusSnoozedTime = UserDefaultsValue<Date?>(key: "alertMissedBolusSnoozedTime", default: nil)
    static let alertMissedBolusIsSnoozed = UserDefaultsValue<Bool>(key: "alertMissedBolusIsSnoozed", default: false)
    static let alertMissedBolusQuiet = UserDefaultsValue<Bool>(key: "alertMissedBolusQuiet", default: false)
    static let alertMissedBolusRepeat = UserDefaultsValue<String>(key: "alertMissedBolusRepeat", default: "Never")
    static let alertMissedBolusDayTime = UserDefaultsValue<Bool>(key: "alertMissedBolusDayTime", default: false)
    static let alertMissedBolusNightTime = UserDefaultsValue<Bool>(key: "alertMissedBolusNightTime", default: false)
    static let alertMissedBolusSound = UserDefaultsValue<String>(key: "alertMissedBolusSound", default: "Dhol_Shuffleloop")
    static let alertMissedBolusAudible = UserDefaultsValue<String>(key: "alertMissedBolusAudible", default: "Always")
    static let alertMissedBolusDayTimeAudible = UserDefaultsValue<Bool>(key: "alertMissedBolusDayTimeAudible", default: true)
    static let alertMissedBolusNightTimeAudible = UserDefaultsValue<Bool>(key: "alertMissedBolusNightTimeAudible", default: true)
    static let alertMissedBolusAutosnooze = UserDefaultsValue<String>(key: "alertMissedBolusAutosnooze", default: "Never")
    static let alertMissedBolusAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertMissedBolusAutosnoozeDay", default: false)
    static let alertMissedBolusAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertMissedBolusAutosnoozeNight", default: false)

    static let alertSAGEActive = UserDefaultsValue<Bool>(key: "alertSAGEActive", default: false)
    static let alertSAGE = UserDefaultsValue<Int>(key: "alertSAGE", default: 8) // Hours
    static let alertSAGEQuiet = UserDefaultsValue<Bool>(key: "alertSAGEQuiet", default: false)
    static let alertSAGERepeat = UserDefaultsValue<String>(key: "alertSAGERepeat", default: "Never")
    static let alertSAGEDayTime = UserDefaultsValue<Bool>(key: "alertSAGEDayTime", default: false)
    static let alertSAGENightTime = UserDefaultsValue<Bool>(key: "alertSAGENightTime", default: false)
    static let alertSAGEAudible = UserDefaultsValue<String>(key: "alertSAGEAudible", default: "Always")
    static let alertSAGEDayTimeAudible = UserDefaultsValue<Bool>(key: "alertSAGEDayTimeAudible", default: true)
    static let alertSAGENightTimeAudible = UserDefaultsValue<Bool>(key: "alertSAGENightTimeAudible", default: true)
    static let alertSAGESnooze = UserDefaultsValue<Int>(key: "alertSAGESnooze", default: 2) // Hours
    static let alertSAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertSAGESnoozedTime", default: nil)
    static let alertSAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertSAGEIsSnoozed", default: false)
    static let alertSAGESound = UserDefaultsValue<String>(key: "alertSAGESound", default: "Wake_Up_Will_You")
    static let alertSAGEAutosnooze = UserDefaultsValue<String>(key: "alertSAGEAutosnooze", default: "At night")
    static let alertSAGEAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertSAGEAutosnoozeDay", default: false)
    static let alertSAGEAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertSAGEAutosnoozeNight", default: true)

    static let alertCAGEActive = UserDefaultsValue<Bool>(key: "alertCAGEActive", default: false)
    static let alertCAGE = UserDefaultsValue<Int>(key: "alertCAGE", default: 4) // Hours
    static let alertCAGEQuiet = UserDefaultsValue<Bool>(key: "alertCAGEQuiet", default: false)
    static let alertCAGERepeat = UserDefaultsValue<String>(key: "alertCAGERepeat", default: "Never")
    static let alertCAGEDayTime = UserDefaultsValue<Bool>(key: "alertCAGEDayTime", default: false)
    static let alertCAGENightTime = UserDefaultsValue<Bool>(key: "alertCAGENightTime", default: false)
    static let alertCAGEAudible = UserDefaultsValue<String>(key: "alertCAGEAudible", default: "Always")
    static let alertCAGEDayTimeAudible = UserDefaultsValue<Bool>(key: "alertCAGEDayTimeAudible", default: true)
    static let alertCAGENightTimeAudible = UserDefaultsValue<Bool>(key: "alertCAGENightTimeAudible", default: true)
    static let alertCAGESnooze = UserDefaultsValue<Int>(key: "alertCAGESnooze", default: 2) // Hours
    static let alertCAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertCAGESnoozedTime", default: nil)
    static let alertCAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertCAGEIsSnoozed", default: false)
    static let alertCAGESound = UserDefaultsValue<String>(key: "alertCAGESound", default: "Wake_Up_Will_You")
    static let alertCAGEAutosnooze = UserDefaultsValue<String>(key: "alertCAGEAutosnooze", default: "At night")
    static let alertCAGEAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertCAGEAutosnoozeDay", default: false)
    static let alertCAGEAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertCAGEAutosnoozeNight", default: true)

    static let alertAppInactive = UserDefaultsValue<Bool>(key: "alertAppInactive", default: false)

    static let alertTemporaryActive = UserDefaultsValue<Bool>(key: "alertTemporaryActive", default: false)
    static let alertTemporaryBelow = UserDefaultsValue<Bool>(key: "alertTemporaryBelow", default: true)
    static let alertTemporaryBG = UserDefaultsValue<Float>(key: "alertTemporaryBG", default: 90.0)
    static let alertTemporaryBGRepeat = UserDefaultsValue<Bool>(key: "alertTemporaryBGRepeat", default: false)
    static let alertTemporaryBGAudible = UserDefaultsValue<Bool>(key: "alertTemporaryBGRepeatAudible", default: true)
    static let alertTemporarySound = UserDefaultsValue<String>(key: "alertTemporarySound", default: "Indeed")

    static let alertOverrideStart = UserDefaultsValue<Bool>(key: "alertOverrideStart", default: false)
    static let alertOverrideStartQuiet = UserDefaultsValue<Bool>(key: "alertOverrideStartQuiet", default: false)
    static let alertOverrideStartRepeat = UserDefaultsValue<String>(key: "alertOverrideStartRepeat", default: "Never")
    static let alertOverrideStartDayTime = UserDefaultsValue<Bool>(key: "alertOverrideStartDayTime", default: false)
    static let alertOverrideStartNightTime = UserDefaultsValue<Bool>(key: "alertOverrideStartNightTime", default: false)
    static let alertOverrideStartAudible = UserDefaultsValue<String>(key: "alertOverrideStartRepeatAudible", default: "Always")
    static let alertOverrideStartDayTimeAudible = UserDefaultsValue<Bool>(key: "alertOverrideStartDayTimeAudible", default: true)
    static let alertOverrideStartNightTimeAudible = UserDefaultsValue<Bool>(key: "alertOverrideStartNightTimeAudible", default: true)
    static let alertOverrideStartSound = UserDefaultsValue<String>(key: "alertOverrideStartSound", default: "Ending_Reached")
    static let alertOverrideStartSnoozedTime = UserDefaultsValue<Date?>(key: "alertOverrideStartSnoozedTime", default: nil)
    static let alertOverrideStartIsSnoozed = UserDefaultsValue<Bool>(key: "alertOverrideStartIsSnoozed", default: false)
    static let alertOverrideStartAutosnooze = UserDefaultsValue<String>(key: "alertOverrideStartAutosnooze", default: "Never")
    static let alertOverrideStartAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertOverrideStartAutosnoozeDay", default: false)
    static let alertOverrideStartAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertOverrideStartAutosnoozeNight", default: false)

    static let alertOverrideEnd = UserDefaultsValue<Bool>(key: "alertOverrideEnd", default: false)
    static let alertOverrideEndQuiet = UserDefaultsValue<Bool>(key: "alertOverrideEndQuiet", default: false)
    static let alertOverrideEndRepeat = UserDefaultsValue<String>(key: "alertOverrideEndRepeat", default: "Never")
    static let alertOverrideEndDayTime = UserDefaultsValue<Bool>(key: "alertOverrideEndDayTime", default: false)
    static let alertOverrideEndNightTime = UserDefaultsValue<Bool>(key: "alertOverrideEndNightTime", default: false)
    static let alertOverrideEndAudible = UserDefaultsValue<String>(key: "alertOverrideEndRepeatAudible", default: "Always")
    static let alertOverrideEndDayTimeAudible = UserDefaultsValue<Bool>(key: "alertOverrideEndDayTimeAudible", default: true)
    static let alertOverrideEndNightTimeAudible = UserDefaultsValue<Bool>(key: "alertOverrideEndNightTimeAudible", default: true)
    static let alertOverrideEndSound = UserDefaultsValue<String>(key: "alertOverrideEndSound", default: "Alert_Tone_Busy")
    static let alertOverrideEndSnoozedTime = UserDefaultsValue<Date?>(key: "alertOverrideEndSnoozedTime", default: nil)
    static let alertOverrideEndIsSnoozed = UserDefaultsValue<Bool>(key: "alertOverrideEndIsSnoozed", default: false)
    static let alertOverrideEndAutosnooze = UserDefaultsValue<String>(key: "alertOverrideEndAutosnooze", default: "Never")
    static let alertOverrideEndAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertOverrideEndAutosnoozeDay", default: false)
    static let alertOverrideEndAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertOverrideEndAutosnoozeNight", default: false)

    static let alertTempTargetStart = UserDefaultsValue<Bool>(key: "alertTempTargetStart", default: false)
    static let alertTempTargetStartQuiet = UserDefaultsValue<Bool>(key: "alertTempTargetStartQuiet", default: false)
    static let alertTempTargetStartRepeat = UserDefaultsValue<String>(key: "alertTempTargetStartRepeat", default: "Never")
    static let alertTempTargetStartDayTime = UserDefaultsValue<Bool>(key: "alertTempTargetStartDayTime", default: false)
    static let alertTempTargetStartNightTime = UserDefaultsValue<Bool>(key: "alertTempTargetStartNightTime", default: false)
    static let alertTempTargetStartAudible = UserDefaultsValue<String>(key: "alertTempTargetStartRepeatAudible", default: "Always")
    static let alertTempTargetStartDayTimeAudible = UserDefaultsValue<Bool>(key: "alertTempTargetStartDayTimeAudible", default: true)
    static let alertTempTargetStartNightTimeAudible = UserDefaultsValue<Bool>(key: "alertTempTargetStartNightTimeAudible", default: true)
    static let alertTempTargetStartSound = UserDefaultsValue<String>(key: "alertTempTargetStartSound", default: "Ending_Reached")
    static let alertTempTargetStartSnoozedTime = UserDefaultsValue<Date?>(key: "alertTempTargetStartSnoozedTime", default: nil)
    static let alertTempTargetStartIsSnoozed = UserDefaultsValue<Bool>(key: "alertTempTargetStartIsSnoozed", default: false)
    static let alertTempTargetStartAutosnooze = UserDefaultsValue<String>(key: "alertTempTargetStartAutosnooze", default: "Never")
    static let alertTempTargetStartAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertTempTargetStartAutosnoozeDay", default: false)
    static let alertTempTargetStartAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertTempTargetStartAutosnoozeNight", default: false)

    static let alertTempTargetEnd = UserDefaultsValue<Bool>(key: "alertTempTargetEnd", default: false)
    static let alertTempTargetEndQuiet = UserDefaultsValue<Bool>(key: "alertTempTargetEndQuiet", default: false)
    static let alertTempTargetEndRepeat = UserDefaultsValue<String>(key: "alertTempTargetEndRepeat", default: "Never")
    static let alertTempTargetEndDayTime = UserDefaultsValue<Bool>(key: "alertTempTargetEndDayTime", default: false)
    static let alertTempTargetEndNightTime = UserDefaultsValue<Bool>(key: "alertTempTargetEndNightTime", default: false)
    static let alertTempTargetEndAudible = UserDefaultsValue<String>(key: "alertTempTargetEndRepeatAudible", default: "Always")
    static let alertTempTargetEndDayTimeAudible = UserDefaultsValue<Bool>(key: "alertTempTargetEndDayTimeAudible", default: true)
    static let alertTempTargetEndNightTimeAudible = UserDefaultsValue<Bool>(key: "alertTempTargetEndNightTimeAudible", default: true)
    static let alertTempTargetEndSound = UserDefaultsValue<String>(key: "alertTempTargetEndSound", default: "Alert_Tone_Busy")
    static let alertTempTargetEndSnoozedTime = UserDefaultsValue<Date?>(key: "alertTempTargetEndSnoozedTime", default: nil)
    static let alertTempTargetEndIsSnoozed = UserDefaultsValue<Bool>(key: "alertTempTargetEndIsSnoozed", default: false)
    static let alertTempTargetEndAutosnooze = UserDefaultsValue<String>(key: "alertTempTargetEndAutosnooze", default: "Never")
    static let alertTempTargetEndAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertTempTargetEndAutosnoozeDay", default: false)
    static let alertTempTargetEndAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertTempTargetEndAutosnoozeNight", default: false)

    static let alertPump = UserDefaultsValue<Bool>(key: "alertPump", default: false)
    static let alertPumpAt = UserDefaultsValue<Int>(key: "alertPumpAt", default: 10) // Units
    static let alertPumpQuiet = UserDefaultsValue<Bool>(key: "alertPumpQuiet", default: false)
    static let alertPumpRepeat = UserDefaultsValue<String>(key: "alertPumpRepeat", default: "Never")
    static let alertPumpDayTime = UserDefaultsValue<Bool>(key: "alertPumpDayTime", default: false)
    static let alertPumpNightTime = UserDefaultsValue<Bool>(key: "alertPumpNightTime", default: false)
    static let alertPumpAudible = UserDefaultsValue<String>(key: "alertPumpAudible", default: "Always")
    static let alertPumpDayTimeAudible = UserDefaultsValue<Bool>(key: "alertPumpDayTimeAudible", default: true)
    static let alertPumpNightTimeAudible = UserDefaultsValue<Bool>(key: "alertPumpNightTimeAudible", default: true)
    static let alertPumpSound = UserDefaultsValue<String>(key: "alertPumpSound", default: "Marimba_Descend")
    static let alertPumpSnoozeHours = UserDefaultsValue<Int>(key: "alertPumpSnoozeHours", default: 5) // Hours
    static let alertPumpIsSnoozed = UserDefaultsValue<Bool>(key: "alertPumpIsSnoozed", default: false)
    static let alertPumpSnoozedTime = UserDefaultsValue<Date?>(key: "alertPumpSnoozedTime", default: nil)
    static let alertPumpAutosnooze = UserDefaultsValue<String>(key: "alertPumpAutosnooze", default: "Never")
    static let alertPumpAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertPumpAutosnoozeDay", default: false)
    static let alertPumpAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertPumpAutosnoozeNight", default: false)

    static let alertIOB = UserDefaultsValue<Bool>(key: "alertIOB", default: false)
    static let alertIOBAt = UserDefaultsValue<Double>(key: "alertIOBAt", default: 1.5) // Units
    static let alertIOBNumber = UserDefaultsValue<Int>(key: "alertIOBNumber", default: 3) // Number
    static let alertIOBBolusesWithin = UserDefaultsValue<Int>(key: "alertIOBBolusesWithin", default: 60) // Minutes
    static let alertIOBMaxBoluses = UserDefaultsValue<Int>(key: "alertIOBMaxBoluses", default: 10) // Units
    static let alertIOBQuiet = UserDefaultsValue<Bool>(key: "alertIOBQuiet", default: false)
    static let alertIOBRepeat = UserDefaultsValue<String>(key: "alertIOBRepeat", default: "Always")
    static let alertIOBDayTime = UserDefaultsValue<Bool>(key: "alertIOBDayTime", default: true)
    static let alertIOBNightTime = UserDefaultsValue<Bool>(key: "alertIOBNightTime", default: true)
    static let alertIOBAudible = UserDefaultsValue<String>(key: "alertIOBAudible", default: "Always")
    static let alertIOBDayTimeAudible = UserDefaultsValue<Bool>(key: "alertIOBDayTimeAudible", default: true)
    static let alertIOBNightTimeAudible = UserDefaultsValue<Bool>(key: "alertIOBNightTimeAudible", default: true)
    static let alertIOBSound = UserDefaultsValue<String>(key: "alertIOBSound", default: "Alert_Tone_Ringtone_1")
    static let alertIOBSnoozeHours = UserDefaultsValue<Int>(key: "alertIOBSnoozeHours", default: 1) // Hours
    static let alertIOBIsSnoozed = UserDefaultsValue<Bool>(key: "alertIOBIsSnoozed", default: false)
    static let alertIOBSnoozedTime = UserDefaultsValue<Date?>(key: "alertIOBSnoozedTime", default: nil)
    static let alertIOBAutosnooze = UserDefaultsValue<String>(key: "alertIOBAutosnooze", default: "Never")
    static let alertIOBAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertIOBAutosnoozeDay", default: false)
    static let alertIOBAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertIOBAutosnoozeNight", default: false)

    static let alertCOB = UserDefaultsValue<Bool>(key: "alertCOB", default: false)
    static let alertCOBAt = UserDefaultsValue<Int>(key: "alertCOBAt", default: 50) // Units
    static let alertCOBQuiet = UserDefaultsValue<Bool>(key: "alertCOBQuiet", default: false)
    static let alertCOBRepeat = UserDefaultsValue<String>(key: "alertCOBRepeat", default: "Always")
    static let alertCOBDayTime = UserDefaultsValue<Bool>(key: "alertCOBDayTime", default: true)
    static let alertCOBNightTime = UserDefaultsValue<Bool>(key: "alertCOBNightTime", default: true)
    static let alertCOBAudible = UserDefaultsValue<String>(key: "alertCOBAudible", default: "Always")
    static let alertCOBDayTimeAudible = UserDefaultsValue<Bool>(key: "alertCOBDayTimeAudible", default: true)
    static let alertCOBNightTimeAudible = UserDefaultsValue<Bool>(key: "alertCOBNightTimeAudible", default: true)
    static let alertCOBSound = UserDefaultsValue<String>(key: "alertCOBSound", default: "Alert_Tone_Ringtone_2")
    static let alertCOBSnoozeHours = UserDefaultsValue<Int>(key: "alertCOBSnoozeHours", default: 1) // Hours
    static let alertCOBIsSnoozed = UserDefaultsValue<Bool>(key: "alertCOBIsSnoozed", default: false)
    static let alertCOBSnoozedTime = UserDefaultsValue<Date?>(key: "alertCOBSnoozedTime", default: nil)
    static let alertCOBAutosnooze = UserDefaultsValue<String>(key: "alertCOBAutosnooze", default: "Never")
    static let alertCOBAutosnoozeDay = UserDefaultsValue<Bool>(key: "alertCOBAutosnoozeDay", default: false)
    static let alertCOBAutosnoozeNight = UserDefaultsValue<Bool>(key: "alertCOBAutosnoozeNight", default: false)

    static let alertBatteryActive = UserDefaultsValue<Bool>(key: "alertBatteryActive", default: false)
    static let alertBatteryLevel = UserDefaultsValue<Int>(key: "alertBatteryLevel", default: 25)
    static let alertBatterySound = UserDefaultsValue<String>(key: "alertBatterySound", default: "Machine_Charge")
    static let alertBatteryRepeat = UserDefaultsValue<Bool>(key: "alertBatteryRepeat", default: true)
    static let alertBatteryIsSnoozed = UserDefaultsValue<Bool>(key: "alertBatteryIsSnoozed", default: false)
    static let alertBatterySnoozedTime = UserDefaultsValue<Date?>(key: "alertBatterySnoozedTime", default: nil)
    static let alertBatterySnoozeHours = UserDefaultsValue<Int>(key: "alertBatterySnoozeHours", default: 1)
    static var deviceBatteryLevel: UserDefaultsValue<Double> = UserDefaultsValue(key: "deviceBatteryLevel", default: 100.0)

    static let alertBatteryDropActive = UserDefaultsValue<Bool>(key: "alertBatteryDropActive", default: false)
    static let alertBatteryDropPercentage = UserDefaultsValue<Int>(key: "alertBatteryDropPercentage", default: 5)
    static let alertBatteryDropPeriod = UserDefaultsValue<Int>(key: "alertBatteryDropPeriod", default: 15)
    static let alertBatteryDropSound = UserDefaultsValue<String>(key: "alertBatteryDropSound", default: "Machine_Charge")
    static let alertBatteryDropRepeat = UserDefaultsValue<Bool>(key: "alertBatteryDropRepeat", default: true)
    static let alertBatteryDropIsSnoozed = UserDefaultsValue<Bool>(key: "alertBatteryDropIsSnoozed", default: false)
    static let alertBatteryDropSnoozedTime = UserDefaultsValue<Date?>(key: "alertBatteryDropSnoozedTime", default: nil)
    static let alertBatteryDropSnoozeHours = UserDefaultsValue<Int>(key: "alertBatteryDropSnoozeHours", default: 1)

    static let alertRecBolusActive = UserDefaultsValue<Bool>(key: "alertRecBolusActive", default: false)
    static let alertRecBolusLevel = UserDefaultsValue<Double>(key: "alertRecBolusLevel", default: 1) // Unit[s]
    static let alertRecBolusSound = UserDefaultsValue<String>(key: "alertRecBolusSound", default: "Dhol_Shuffleloop")
    static let alertRecBolusRepeat = UserDefaultsValue<Bool>(key: "alertRecBolusRepeat", default: false)
    static let alertRecBolusIsSnoozed = UserDefaultsValue<Bool>(key: "alertRecBolusIsSnoozed", default: false)
    static let alertRecBolusSnooze = UserDefaultsValue<Int>(key: "alertRecBolusSnooze", default: 5)
    static let alertRecBolusSnoozedTime = UserDefaultsValue<Date?>(key: "alertRecBolusSnoozedTime", default: nil)
    static var deviceRecBolus: UserDefaultsValue<Double> = UserDefaultsValue(key: "deviceRecBolus", default: 0.0)

    // What version is the cache valid for
    static let cachedForVersion = UserDefaultsValue<String?>(key: "cachedForVersion", default: nil)

    // Caching of latest version
    static let latestVersion = UserDefaultsValue<String?>(key: "latestVersion", default: nil)
    static let latestVersionChecked = UserDefaultsValue<Date?>(key: "latestVersionChecked", default: nil)

    // Caching of blacklisted version
    static let currentVersionBlackListed = UserDefaultsValue<Bool>(key: "currentVersionBlackListed", default: false)

    // Tracking notifications to manage frequency
    static let lastBlacklistNotificationShown = UserDefaultsValue<Date?>(key: "lastBlacklistNotificationShown", default: nil)
    static let lastVersionUpdateNotificationShown = UserDefaultsValue<Date?>(key: "lastVersionUpdateNotificationShown", default: nil)

    // Tracking the last time the expiration notification was shown
    static let lastExpirationNotificationShown = UserDefaultsValue<Date?>(key: "lastExpirationNotificationShown", default: nil)
}
