//
//  UserDefaults.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/4/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

class UserDefaultsRepository {

    // DisplayValues total
    static let infoDataTotal = UserDefaultsValue<Int>(key: "infoDataTotal", default: 0)
    static let infoNames = UserDefaultsValue<[String]>(key: "infoNames", default: [
        "IOB",
        "COB",
        "Basal",
        "Override",
        "Battery",
        "Pump",
        "SAGE",
        "CAGE",
        "Rec. Bolus",
        "Pred. Min-Max"])
    static let infoSort = UserDefaultsValue<[Int]>(key: "infoSort", default: [0,1,2,3,4,5,6,7,8,9])
    static let infoVisible = UserDefaultsValue<[Bool]>(key: "infoVisible", default: [true,true,true,true,true,true,true,true,true,true])
    
    // Nightscout Settings
    static let url = UserDefaultsValue<String>(key: "url", default: "")
    static let token = UserDefaultsValue<String>(key: "token", default: "")
    static let units = UserDefaultsValue<String>(key: "units", default: "mg/dL")
    
    // Dexcom Share Settings
    static let shareUserName = UserDefaultsValue<String>(key: "shareUserName", default: "")
    static let sharePassword = UserDefaultsValue<String>(key: "sharePassword", default: "")
    static let shareServer = UserDefaultsValue<String>(key: "shareServer", default: "US")
    
    // Graph Settings
    static let chartScaleX = UserDefaultsValue<Float>(key: "chartScaleX", default: 18.0)
    static let showDots = UserDefaultsValue<Bool>(key: "showDots", default: true)
    static let showLines = UserDefaultsValue<Bool>(key: "showLines", default: true)
    static let offsetCarbsBolus = UserDefaultsValue<Bool>(key: "offsetCarbsBolus", default: true)
    static let hoursToLoad = UserDefaultsValue<Int>(key: "hoursToLoad", default: 24)
    static let predictionToLoad = UserDefaultsValue<Double>(key: "predictionToLoad", default: 1)
    static let minBasalScale = UserDefaultsValue<Double>(key: "minBasalScale", default: 5.0)
    static let minBGScale = UserDefaultsValue<Float>(key: "minBGScale", default: 250.0)
    static let minBGValue = UserDefaultsValue<Float>(key: "minBGValue", default: 40.0)
    static let overrideDisplayLocation = UserDefaultsValue<Float>(key: "overrideDisplayLocation", default: 40.0)
    static let lowLine = UserDefaultsValue<Float>(key: "lowLine", default: 70.0)
    static let highLine = UserDefaultsValue<Float>(key: "highLine", default: 180.0)
    
    // General Settings
    static let colorBGText = UserDefaultsValue<Bool>(key: "colorBGText", default: true)
    static let speakBG = UserDefaultsValue<Bool>(key: "speakBG", default: false)
    static let backgroundRefreshFrequency = UserDefaultsValue<Double>(key: "backgroundRefreshFrequency", default: 1)
    static let backgroundRefresh = UserDefaultsValue<Bool>(key: "backgroundRefresh", default: true)
    static let appBadge = UserDefaultsValue<Bool>(key: "appBadge", default: true)
    static let dimScreenWhenIdle = UserDefaultsValue<Int>(key: "dimScreenWhenIdle", default: 0)
    static let forceDarkMode = UserDefaultsValue<Bool>(key: "forceDarkMode", default: true)
    static let persistentNotification = UserDefaultsValue<Bool>(key: "persistentNotification", default: false)
    static let persistentNotificationLastBGTime = UserDefaultsValue<TimeInterval>(key: "persistentNotificationLastBGTime", default: 0)
    static let screenlockSwitchState = UserDefaultsValue<Bool>(
        key: "screenlockSwitchState",
        default: UIApplication.shared.isIdleTimerDisabled,
        onChange: { screenlock in
            UIApplication.shared.isIdleTimerDisabled = screenlock
    })
    
    // Debug Settings
        static let downloadBasal = UserDefaultsValue<Bool>(key: "downloadBasal", default: true)
        static let downloadBolus = UserDefaultsValue<Bool>(key: "downloadBolus", default: true)
        static let downloadCarbs = UserDefaultsValue<Bool>(key: "downloadCarbs", default: true)
        static let downloadPrediction = UserDefaultsValue<Bool>(key: "downloadPrediction", default: true)
        static let graphBasal = UserDefaultsValue<Bool>(key: "graphBasal", default: true)
        static let graphBolus = UserDefaultsValue<Bool>(key: "graphBolus", default: true)
        static let graphCarbs = UserDefaultsValue<Bool>(key: "graphCarbs", default: true)
        static let graphPrediction = UserDefaultsValue<Bool>(key: "graphPrediction", default: true)
        static let debugLog = UserDefaultsValue<Bool>(key: "debugLog", default: false)
        static let viewRefreshDelay = UserDefaultsValue<Double>(key: "viewRefreshDelay", default: 15.0)
    
    
    
    // Watch Calendar Settings
    static let calendarIdentifier = UserDefaultsValue<String>(key: "calendarIdentifier", default: "")
    static let savedEventID = UserDefaultsValue<String>(key: "savedEventID", default: "")
    static let lastCalendarStartDate = UserDefaultsValue<Date?>(key: "lastCalendarStartDate", default: nil)
    static let writeCalendarEvent = UserDefaultsValue<Bool>(key: "writeCalendarEvent", default: false)
    static let watchLine1 = UserDefaultsValue<String>(key: "watchLine1", default: "%BG% %DIRECTION% %DELTA% %MINAGO%")
    static let watchLine2 = UserDefaultsValue<String>(key: "watchLine2", default: "C:%COB% I:%IOB% B:%BASAL%")
    
    // Alarm Settings
    static let systemOutputVolume = UserDefaultsValue<Float>(key: "systemOutputVolume", default: 0.5)
    static let fadeInTimeInterval = UserDefaultsValue<TimeInterval>(key: "fadeInTimeInterval", default: 0)
    static let vibrate = UserDefaultsValue<Bool>(key: "vibrate", default: true)
    static let overrideSystemOutputVolume = UserDefaultsValue<Bool>(key: "overrideSystemOutputVolume", default: true)
    static let forcedOutputVolume = UserDefaultsValue<Float>(key: "forcedOutputVolume", default: 0.5)
    
    
    // Alerts
    
    static let quietHourStart = UserDefaultsValue<Date?>(key: "quietHourStart", default: nil)
    static let quietHourEnd = UserDefaultsValue<Date?>(key: "quietHourEnd", default: nil)
    
    static let snoozedBGReadingTime = UserDefaultsValue<TimeInterval?>(key: "snoozedBGReadingTime", default: 0)
    
    static let alertCageInsertTime = UserDefaultsValue<TimeInterval>(key: "alertCageInsertTime", default: 0)
    static let alertSageInsertTime = UserDefaultsValue<TimeInterval>(key: "alertSageInsertTime", default: 0)
    
    static let alertSnoozeAllTime = UserDefaultsValue<Date?>(key: "alertSnoozeAllTime", default: nil)
    static let alertSnoozeAllIsSnoozed = UserDefaultsValue<Bool>(key: "alertSnoozeAllIsSnoozed", default: false)
    
    static let alertUrgentLowActive = UserDefaultsValue<Bool>(key: "alertUrgentLowActive", default: false)
    static let alertUrgentLowBG = UserDefaultsValue<Float>(key: "alertUrgentLowBG", default: 55.0)
    static let alertUrgentLowSnooze = UserDefaultsValue<Int>(key: "alertUrgentLowSnooze", default: 5)
    static let alertUrgentLowSnoozedTime = UserDefaultsValue<Date?>(key: "alertUrgentLowSnoozedTime", default: nil)
    static let alertUrgentLowIsSnoozed = UserDefaultsValue<Bool>(key: "alertUrgentLowIsSnoozed", default: false)
    static let alertUrgentLowRepeat = UserDefaultsValue<Bool>(key: "alertUrgentLowRepeat", default: true)
    static let alertUrgentLowSound = UserDefaultsValue<String>(key: "alertUrgentLowSound", default: "Indeed")
    
    static let alertLowActive = UserDefaultsValue<Bool>(key: "alertLowActive", default: false)
    static let alertLowBG = UserDefaultsValue<Float>(key: "alertLowBG", default: 70.0)
    static let alertLowSnooze = UserDefaultsValue<Int>(key: "alertLowSnooze", default: 5)
    static let alertLowSnoozedTime = UserDefaultsValue<Date?>(key: "alertLowSnoozedTime", default: nil)
    static let alertLowIsSnoozed = UserDefaultsValue<Bool>(key: "alertLowIsSnoozed", default: false)
    static let alertLowRepeat = UserDefaultsValue<Bool>(key: "alertLowRepeat", default: true)
    static let alertLowSound = UserDefaultsValue<String>(key: "alertLowSound", default: "Indeed")
    
    static let alertHighActive = UserDefaultsValue<Bool>(key: "alertHighActive", default: false)
    static let alertHighBG = UserDefaultsValue<Float>(key: "alertHighBG", default: 180.0)
    static let alertHighPersistent = UserDefaultsValue<Int>(key: "alertHighPersistent", default: 60)
    static let alertHighSnooze = UserDefaultsValue<Int>(key: "alertHighSnooze", default: 60)
    static let alertHighSnoozedTime = UserDefaultsValue<Date?>(key: "alertHighSnoozedTime", default: nil)
    static let alertHighIsSnoozed = UserDefaultsValue<Bool>(key: "alertHighIsSnoozed", default: false)
    static let alertHighRepeat = UserDefaultsValue<Bool>(key: "alertHighRepeat", default: true)
    static let alertHighSound = UserDefaultsValue<String>(key: "alertHighSound", default: "Indeed")
    
    static let alertUrgentHighActive = UserDefaultsValue<Bool>(key: "alertUrgentHighActive", default: false)
    static let alertUrgentHighBG = UserDefaultsValue<Float>(key: "alertUrgentHighBG", default: 250.0)
    static let alertUrgentHighSnooze = UserDefaultsValue<Int>(key: "alertUrgentHighSnooze", default: 30)
    static let alertUrgentHighSnoozedTime = UserDefaultsValue<Date?>(key: "alertUrgentHighSnoozedTime", default: nil)
    static let alertUrgentHighIsSnoozed = UserDefaultsValue<Bool>(key: "alertUrgentHighIsSnoozed", default: false)
    static let alertUrgentHighRepeat = UserDefaultsValue<Bool>(key: "alertUrgentHighRepeat", default: true)
    static let alertUrgentHighSound = UserDefaultsValue<String>(key: "alertUrgentHighSound", default: "Indeed")

    
    static let alertFastDropActive = UserDefaultsValue<Bool>(key: "alertFastDropDeltaActive", default: false)
    static let alertFastDropSnooze = UserDefaultsValue<Int>(key: "alertFastDropDeltaSnooze", default: 10)
    static let alertFastDropDelta = UserDefaultsValue<Float>(key: "alertFastDropDelta", default: 10.0)
    static let alertFastDropReadings = UserDefaultsValue<Int>(key: "alertFastDropReadings", default: 3)
    static let alertFastDropUseLimit = UserDefaultsValue<Bool>(key: "alertFastDropUseLimit", default: false)
    static let alertFastDropBelowBG = UserDefaultsValue<Float>(key: "alertFastDropBelowBG", default: 120.0)
    static let alertFastDropSnoozedTime = UserDefaultsValue<Date?>(key: "alertFastDropSnoozedTime", default: nil)
    static let alertFastDropIsSnoozed = UserDefaultsValue<Bool>(key: "alertFastDropIsSnoozed", default: false)
    static let alertFastDropRepeat = UserDefaultsValue<Bool>(key: "alertFastDropRepeat", default: true)
    static let alertFastDropSound = UserDefaultsValue<String>(key: "alertFastDropSound", default: "Indeed")
    
    static let alertFastRiseActive = UserDefaultsValue<Bool>(key: "alertFastRiseDeltaActive", default: false)
    static let alertFastRiseSnooze = UserDefaultsValue<Int>(key: "alertFastRiseDeltaSnooze", default: 10)
    static let alertFastRiseDelta = UserDefaultsValue<Float>(key: "alertFastRiseDelta", default: 10.0)
    static let alertFastRiseReadings = UserDefaultsValue<Int>(key: "alertFastRiseReadings", default: 3)
    static let alertFastRiseUseLimit = UserDefaultsValue<Bool>(key: "alertFastRiseUseLimit", default: false)
    static let alertFastRiseAboveBG = UserDefaultsValue<Float>(key: "alertFastRiseAboveBG", default: 200.0)
    static let alertFastRiseSnoozedTime = UserDefaultsValue<Date?>(key: "alertFastRiseSnoozedTime", default: nil)
    static let alertFastRiseIsSnoozed = UserDefaultsValue<Bool>(key: "alertFastRiseIsSnoozed", default: false)
    static let alertFastRiseRepeat = UserDefaultsValue<Bool>(key: "alertFastRiseRepeat", default: true)
    static let alertFastRiseSound = UserDefaultsValue<String>(key: "alertFastRiseSound", default: "Indeed")
    
    
    static let alertMissedReadingActive = UserDefaultsValue<Bool>(key: "alertMissedReadingActive", default: false)
    static let alertMissedReading = UserDefaultsValue<Int>(key: "alertMissedReading", default: 30)
    static let alertMissedReadingSnooze = UserDefaultsValue<Int>(key: "alertMissedReadingSnooze", default: 30)
    static let alertMissedReadingSnoozedTime = UserDefaultsValue<Date?>(key: "alertMissedReadingSnoozedTime", default: nil)
    static let alertMissedReadingIsSnoozed = UserDefaultsValue<Bool>(key: "alertMissedReadingIsSnoozed", default: false)
    static let alertMissedReadingRepeat = UserDefaultsValue<Bool>(key: "alertMissedReadingRepeat", default: true)
    static let alertMissedReadingSound = UserDefaultsValue<String>(key: "alertMissedReadingSound", default: "Indeed")
    
    
    static let alertNotLoopingActive = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: false)
    static let alertNotLooping = UserDefaultsValue<Int>(key: "alertNotLooping", default: 30)
    static let alertNotLoopingSnooze = UserDefaultsValue<Int>(key: "alertNotLoopingSnooze", default: 30)
    static let alertNotLoopingUseLimits = UserDefaultsValue<Bool>(key: "alertNotLoopingUseLimits", default: false)
    static let alertNotLoopingLowerLimit = UserDefaultsValue<Float>(key: "alertNotLoopingBelowBG", default: 100.0)
    static let alertNotLoopingUpperLimit = UserDefaultsValue<Float>(key: "alertNotLoopingAboveBG", default: 160.0)
    static let alertNotLoopingSnoozedTime = UserDefaultsValue<Date?>(key: "alertNotLoopingSnoozedTime", default: nil)
    static let alertNotLoopingIsSnoozed = UserDefaultsValue<Bool>(key: "alertNotLoopingIsSnoozed", default: false)
    static let alertNotLoopingRepeat = UserDefaultsValue<Bool>(key: "alertNotLoopingRepeat", default: true)
    static let alertNotLoopingSound = UserDefaultsValue<String>(key: "alertNotLoopingSound", default: "Indeed")
    static let alertLastLoopTime = UserDefaultsValue<TimeInterval>(key: "alertLastLoopTime", default: 0)
    
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
    static let alertMissedBolusRepeat = UserDefaultsValue<Bool>(key: "alertMissedBolusRepeat", default: false)
    static let alertMissedBolusSound = UserDefaultsValue<String>(key: "alertMissedBolusSound", default: "Indeed")
    
    static let alertSAGEActive = UserDefaultsValue<Bool>(key: "alertSAGEActive", default: false)
    static let alertSAGE = UserDefaultsValue<Int>(key: "alertSAGE", default: 8) //Hours
    static let alertSAGEQuiet = UserDefaultsValue<Bool>(key: "alertSAGEQuiet", default: false)
    static let alertSAGERepeat = UserDefaultsValue<Bool>(key: "alertSAGERepeat", default: false)
    static let alertSAGESnooze = UserDefaultsValue<Int>(key: "alertSAGESnooze", default: 2) //Hours
    static let alertSAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertSAGESnoozedTime", default: nil)
    static let alertSAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertSAGEIsSnoozed", default: false)
    static let alertSAGESound = UserDefaultsValue<String>(key: "alertSAGESound", default: "Indeed")
    
    static let alertCAGEActive = UserDefaultsValue<Bool>(key: "alertCAGEActive", default: false)
    static let alertCAGE = UserDefaultsValue<Int>(key: "alertCAGE", default: 4) //Hours
    static let alertCAGEQuiet = UserDefaultsValue<Bool>(key: "alertCAGEQuiet", default: false)
    static let alertCAGERepeat = UserDefaultsValue<Bool>(key: "alertCAGERepeat", default: false)
    static let alertCAGESnooze = UserDefaultsValue<Int>(key: "alertCAGESnooze", default: 2) //Hours
    static let alertCAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertCAGESnoozedTime", default: nil)
    static let alertCAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertCAGEIsSnoozed", default: false)
    static let alertCAGESound = UserDefaultsValue<String>(key: "alertCAGESound", default: "Indeed")
    
    static let alertAppInactive = UserDefaultsValue<Bool>(key: "alertAppInactive", default: false)
    
    static let alertTemporaryActive = UserDefaultsValue<Bool>(key: "alertTemporaryActive", default: false)
    static let alertTemporaryBelow = UserDefaultsValue<Bool>(key: "alertTemporaryBelow", default: true)
    static let alertTemporaryBG = UserDefaultsValue<Float>(key: "alertTemporaryBG", default: 90.0)
    static let alertTemporaryBGRepeat = UserDefaultsValue<Bool>(key: "alertTemporaryBGRepeat", default: true)
    static let alertTemporarySound = UserDefaultsValue<String>(key: "alertTemporarySound", default: "Indeed")
    
    static let alertOverrideStart = UserDefaultsValue<Bool>(key: "alertOverrideStart", default: false)
    static let alertOverrideStartQuiet = UserDefaultsValue<Bool>(key: "alertOverrideStartQuiet", default: false)
    static let alertOverrideStartRepeat = UserDefaultsValue<Bool>(key: "alertOverrideStartRepeat", default: false)
    static let alertOverrideStartSound = UserDefaultsValue<String>(key: "alertOverrideStartSound", default: "Alert_Tone_Busy")
    static let alertOverrideStartSnoozedTime = UserDefaultsValue<Date?>(key: "alertOverrideStartSnoozedTime", default: nil)
    static let alertOverrideStartIsSnoozed = UserDefaultsValue<Bool>(key: "alertOverrideStartIsSnoozed", default: false)
    
    static let alertOverrideEnd = UserDefaultsValue<Bool>(key: "alertOverrideEnd", default: false)
    static let alertOverrideEndQuiet = UserDefaultsValue<Bool>(key: "alertOverrideEndQuiet", default: false)
    static let alertOverrideEndRepeat = UserDefaultsValue<Bool>(key: "alertOverrideEndRepeat", default: false)
    static let alertOverrideEndSound = UserDefaultsValue<String>(key: "alertOverrideEndSound", default: "Ending_Reached")
    static let alertOverrideEndSnoozedTime = UserDefaultsValue<Date?>(key: "alertOverrideEndSnoozedTime", default: nil)
    static let alertOverrideEndIsSnoozed = UserDefaultsValue<Bool>(key: "alertOverrideEndIsSnoozed", default: false)
    
}
