//
//  UserDefaults.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/4/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//
//
//
//
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
        "Pred."])
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
    static let smallGraphTreatments = UserDefaultsValue<Bool>(key: "smallGraphTreatments", default: true)
    static let showValues = UserDefaultsValue<Bool>(key: "showValues", default: true)
    static let showAbsorption = UserDefaultsValue<Bool>(key: "showAbsorption", default: true)
    static let showLines = UserDefaultsValue<Bool>(key: "showLines", default: true)
    static let hoursToLoad = UserDefaultsValue<Int>(key: "hoursToLoad", default: 24)
    static let predictionToLoad = UserDefaultsValue<Double>(key: "predictionToLoad", default: 1)
    static let minBasalScale = UserDefaultsValue<Double>(key: "minBasalScale", default: 5.0)
    static let minBGScale = UserDefaultsValue<Float>(key: "minBGScale", default: 250.0)
    static let showDIALines = UserDefaultsValue<Bool>(key: "showDIAMarkers", default: true)
    static let lowLine = UserDefaultsValue<Float>(key: "lowLine", default: 70.0)
    static let highLine = UserDefaultsValue<Float>(key: "highLine", default: 180.0)
    static let smallGraphHeight = UserDefaultsValue<Int>(key: "smallGraphHeight", default: 40)
    
    
    // General Settings
    static let colorBGText = UserDefaultsValue<Bool>(key: "colorBGText", default: true)
    static let showStats = UserDefaultsValue<Bool>(key: "showStats", default: true)
    static let useIFCC = UserDefaultsValue<Bool>(key: "useIFCC", default: false)
    static let showSmallGraph = UserDefaultsValue<Bool>(key: "showSmallGraph", default: true)
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
    
    // Advanced Settings
    static let onlyDownloadBG = UserDefaultsValue<Bool>(key: "onlyDownloadBG", default: false)
    static let downloadTreatments = UserDefaultsValue<Bool>(key: "downloadTreatments", default: true)
    static let downloadPrediction = UserDefaultsValue<Bool>(key: "downloadPrediction", default: true)
    static let graphOtherTreatments = UserDefaultsValue<Bool>(key: "graphOtherTreatments", default: true)
    static let graphBasal = UserDefaultsValue<Bool>(key: "graphBasal", default: true)
    static let graphBolus = UserDefaultsValue<Bool>(key: "graphBolus", default: true)
    static let graphCarbs = UserDefaultsValue<Bool>(key: "graphCarbs", default: true)
    static let debugLog = UserDefaultsValue<Bool>(key: "debugLog", default: false)
    static let alwaysDownloadAllBG = UserDefaultsValue<Bool>(key: "alwaysDownloadAllBG", default: true)
    static let bgUpdateDelay = UserDefaultsValue<Int>(key: "bgUpdateDelay", default: 10)
    
    
    // Watch Calendar Settings
    static let calendarIdentifier = UserDefaultsValue<String>(key: "calendarIdentifier", default: "")
    static let savedEventID = UserDefaultsValue<String>(key: "savedEventID", default: "")
    static let lastCalendarStartDate = UserDefaultsValue<Date?>(key: "lastCalendarStartDate", default: nil)
    static let writeCalendarEvent = UserDefaultsValue<Bool>(key: "writeCalendarEvent", default: false)
    static let watchLine1 = UserDefaultsValue<String>(key: "watchLine1", default: "%BG% %DIRECTION% %DELTA% %MINAGO%")
    static let watchLine2 = UserDefaultsValue<String>(key: "watchLine2", default: "C:%COB% I:%IOB% B:%BASAL%")
    static let saveImage = UserDefaultsValue<Bool>(key: "saveImage", default: false)
    
    // Alarm Settings
    static let systemOutputVolume = UserDefaultsValue<Float>(key: "systemOutputVolume", default: 0.5)
    static let fadeInTimeInterval = UserDefaultsValue<TimeInterval>(key: "fadeInTimeInterval", default: 0)
    static let vibrate = UserDefaultsValue<Bool>(key: "vibrate", default: true)
    static let overrideSystemOutputVolume = UserDefaultsValue<Bool>(key: "overrideSystemOutputVolume", default: true)
    static let forcedOutputVolume = UserDefaultsValue<Float>(key: "forcedOutputVolume", default: 0.5)
    
    
    // Alerts
    
    static let quietHourStart = UserDefaultsValue<Date?>(key: "quietHourStart", default: nil) //eventually need to adjust this to night time instead of quiet hour to clean up
    static let quietHourEnd = UserDefaultsValue<Date?>(key: "quietHourEnd", default: nil) //eventually need to adjust this to night time instead of quiet hour to clean up
    static let nightTime = UserDefaultsValue<Bool>(key: "nightTime", default: false)
    
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
    static let alertUrgentLowRepeat = UserDefaultsValue<String>(key: "alertUrgentLowRepeat", default: "Do not repeat")
    static let alertUrgentLowDayTime = UserDefaultsValue<Bool>(key: "alertUrgentLowDayTime", default: false)
    static let alertUrgentLowNightTime = UserDefaultsValue<Bool>(key: "alertUrgentLowNightTime", default: false)
    static let alertUrgentLowSound = UserDefaultsValue<String>(key: "alertUrgentLowSound", default: "Emergency_Alarm_Siren")
    
    static let alertLowActive = UserDefaultsValue<Bool>(key: "alertLowActive", default: false)
    static let alertLowBG = UserDefaultsValue<Float>(key: "alertLowBG", default: 70.0)
    static let alertLowSnooze = UserDefaultsValue<Int>(key: "alertLowSnooze", default: 5)
    static let alertLowSnoozedTime = UserDefaultsValue<Date?>(key: "alertLowSnoozedTime", default: nil)
    static let alertLowIsSnoozed = UserDefaultsValue<Bool>(key: "alertLowIsSnoozed", default: false)
    static let alertLowRepeat = UserDefaultsValue<String>(key: "alertLowRepeat", default: "Do not repeat")
    static let alertLowDayTime = UserDefaultsValue<Bool>(key: "alertLowDayTime", default: false)
    static let alertLowNightTime = UserDefaultsValue<Bool>(key: "alertLowNightTime", default: false)
    static let alertLowSound = UserDefaultsValue<String>(key: "alertLowSound", default: "Indeed")
    
    static let alertHighActive = UserDefaultsValue<Bool>(key: "alertHighActive", default: false)
    static let alertHighBG = UserDefaultsValue<Float>(key: "alertHighBG", default: 180.0)
    static let alertHighPersistent = UserDefaultsValue<Int>(key: "alertHighPersistent", default: 60)
    static let alertHighSnooze = UserDefaultsValue<Int>(key: "alertHighSnooze", default: 60)
    static let alertHighSnoozedTime = UserDefaultsValue<Date?>(key: "alertHighSnoozedTime", default: nil)
    static let alertHighIsSnoozed = UserDefaultsValue<Bool>(key: "alertHighIsSnoozed", default: false)
    static let alertHighRepeat = UserDefaultsValue<String>(key: "alertHighRepeat", default: "Do not repeat")
    static let alertHighDayTime = UserDefaultsValue<Bool>(key: "alertHighDayTime", default: false)
    static let alertHighNightTime = UserDefaultsValue<Bool>(key: "alertHighNightTime", default: false)
    static let alertHighSound = UserDefaultsValue<String>(key: "alertHighSound", default: "Time_Has_Come")
    
    static let alertUrgentHighActive = UserDefaultsValue<Bool>(key: "alertUrgentHighActive", default: false)
    static let alertUrgentHighBG = UserDefaultsValue<Float>(key: "alertUrgentHighBG", default: 250.0)
    static let alertUrgentHighSnooze = UserDefaultsValue<Int>(key: "alertUrgentHighSnooze", default: 30)
    static let alertUrgentHighSnoozedTime = UserDefaultsValue<Date?>(key: "alertUrgentHighSnoozedTime", default: nil)
    static let alertUrgentHighIsSnoozed = UserDefaultsValue<Bool>(key: "alertUrgentHighIsSnoozed", default: false)
    static let alertUrgentHighRepeat = UserDefaultsValue<String>(key: "alertUrgentHighRepeat", default: "Do not repeat")
    static let alertUrgentHighDayTime = UserDefaultsValue<Bool>(key: "alertUrgentHighDayTime", default: false)
    static let alertUrgentHighNightTime = UserDefaultsValue<Bool>(key: "alertUrgentHighNightTime", default: false)
    static let alertUrgentHighSound = UserDefaultsValue<String>(key: "alertUrgentHighSound", default: "Pager_Beeps")

    
    static let alertFastDropActive = UserDefaultsValue<Bool>(key: "alertFastDropDeltaActive", default: false)
    static let alertFastDropSnooze = UserDefaultsValue<Int>(key: "alertFastDropDeltaSnooze", default: 10)
    static let alertFastDropDelta = UserDefaultsValue<Float>(key: "alertFastDropDelta", default: 10.0)
    static let alertFastDropReadings = UserDefaultsValue<Int>(key: "alertFastDropReadings", default: 3)
    static let alertFastDropUseLimit = UserDefaultsValue<Bool>(key: "alertFastDropUseLimit", default: false)
    static let alertFastDropBelowBG = UserDefaultsValue<Float>(key: "alertFastDropBelowBG", default: 120.0)
    static let alertFastDropSnoozedTime = UserDefaultsValue<Date?>(key: "alertFastDropSnoozedTime", default: nil)
    static let alertFastDropIsSnoozed = UserDefaultsValue<Bool>(key: "alertFastDropIsSnoozed", default: false)
    static let alertFastDropRepeat = UserDefaultsValue<String>(key: "alertFastDropRepeat", default: "Do not repeat")
    static let alertFastDropDayTime = UserDefaultsValue<Bool>(key: "alertFastDropDayTime", default: false)
    static let alertFastDropNightTime = UserDefaultsValue<Bool>(key: "alertFastDropNightTime", default: false)
    static let alertFastDropSound = UserDefaultsValue<String>(key: "alertFastDropSound", default: "Big_Clock_Ticking")
    
    static let alertFastRiseActive = UserDefaultsValue<Bool>(key: "alertFastRiseDeltaActive", default: false)
    static let alertFastRiseSnooze = UserDefaultsValue<Int>(key: "alertFastRiseDeltaSnooze", default: 10)
    static let alertFastRiseDelta = UserDefaultsValue<Float>(key: "alertFastRiseDelta", default: 10.0)
    static let alertFastRiseReadings = UserDefaultsValue<Int>(key: "alertFastRiseReadings", default: 3)
    static let alertFastRiseUseLimit = UserDefaultsValue<Bool>(key: "alertFastRiseUseLimit", default: false)
    static let alertFastRiseAboveBG = UserDefaultsValue<Float>(key: "alertFastRiseAboveBG", default: 200.0)
    static let alertFastRiseSnoozedTime = UserDefaultsValue<Date?>(key: "alertFastRiseSnoozedTime", default: nil)
    static let alertFastRiseIsSnoozed = UserDefaultsValue<Bool>(key: "alertFastRiseIsSnoozed", default: false)
    static let alertFastRiseRepeat = UserDefaultsValue<String>(key: "alertFastRiseRepeat", default: "Do not repeat")
    static let alertFastRiseDayTime = UserDefaultsValue<Bool>(key: "alertFastRiseDayTime", default: false)
    static let alertFastRiseNightTime = UserDefaultsValue<Bool>(key: "alertFastRiseNightTime", default: false)
    static let alertFastRiseSound = UserDefaultsValue<String>(key: "alertFastRiseSound", default: "Cartoon_Fail_Strings_Trumpet")
    
    
    static let alertMissedReadingActive = UserDefaultsValue<Bool>(key: "alertMissedReadingActive", default: false)
    static let alertMissedReading = UserDefaultsValue<Int>(key: "alertMissedReading", default: 30)
    static let alertMissedReadingSnooze = UserDefaultsValue<Int>(key: "alertMissedReadingSnooze", default: 30)
    static let alertMissedReadingSnoozedTime = UserDefaultsValue<Date?>(key: "alertMissedReadingSnoozedTime", default: nil)
    static let alertMissedReadingIsSnoozed = UserDefaultsValue<Bool>(key: "alertMissedReadingIsSnoozed", default: false)
    static let alertMissedReadingRepeat = UserDefaultsValue<String>(key: "alertMissedReadingRepeat", default: "Do not repeat")
    static let alertMissedReadingDayTime = UserDefaultsValue<Bool>(key: "alertMissedReadingDayTime", default: false)
    static let alertMissedReadingNightTime = UserDefaultsValue<Bool>(key: "alertMissedReadingNightTime", default: false)
    static let alertMissedReadingSound = UserDefaultsValue<String>(key: "alertMissedReadingSound", default: "Cartoon_Tip_Toe_Sneaky_Walk")
    
    
    static let alertNotLoopingActive = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: false)
    static let alertNotLooping = UserDefaultsValue<Int>(key: "alertNotLooping", default: 30)
    static let alertNotLoopingSnooze = UserDefaultsValue<Int>(key: "alertNotLoopingSnooze", default: 30)
    static let alertNotLoopingUseLimits = UserDefaultsValue<Bool>(key: "alertNotLoopingUseLimits", default: false)
    static let alertNotLoopingLowerLimit = UserDefaultsValue<Float>(key: "alertNotLoopingBelowBG", default: 100.0)
    static let alertNotLoopingUpperLimit = UserDefaultsValue<Float>(key: "alertNotLoopingAboveBG", default: 160.0)
    static let alertNotLoopingSnoozedTime = UserDefaultsValue<Date?>(key: "alertNotLoopingSnoozedTime", default: nil)
    static let alertNotLoopingIsSnoozed = UserDefaultsValue<Bool>(key: "alertNotLoopingIsSnoozed", default: false)
    static let alertNotLoopingRepeat = UserDefaultsValue<String>(key: "alertNotLoopingRepeat", default: "Do not repeat")
    static let alertNotLoopingDayTime = UserDefaultsValue<Bool>(key: "alertNotLoopingDayTime", default: false)
    static let alertNotLoopingNightTime = UserDefaultsValue<Bool>(key: "alertNotLoopingNightTime", default: false)
    static let alertNotLoopingSound = UserDefaultsValue<String>(key: "alertNotLoopingSound", default: "Sci-Fi_Engine_Shut_Down")
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
    static let alertMissedBolusRepeat = UserDefaultsValue<String>(key: "alertMissedBolusRepeat", default: "Do not repeat")
    static let alertMissedBolusDayTime = UserDefaultsValue<Bool>(key: "alertMissedBolusDayTime", default: false)
    static let alertMissedBolusNightTime = UserDefaultsValue<Bool>(key: "alertMissedBolusNightTime", default: false)
    static let alertMissedBolusSound = UserDefaultsValue<String>(key: "alertMissedBolusSound", default: "Dhol_Shuffleloop")
    
    static let alertSAGEActive = UserDefaultsValue<Bool>(key: "alertSAGEActive", default: false)
    static let alertSAGE = UserDefaultsValue<Int>(key: "alertSAGE", default: 8) //Hours
    static let alertSAGEQuiet = UserDefaultsValue<Bool>(key: "alertSAGEQuiet", default: false)
    static let alertSAGERepeat = UserDefaultsValue<String>(key: "alertSAGERepeat", default: "Do not repeat")
    static let alertSAGEDayTime = UserDefaultsValue<Bool>(key: "alertSAGEDayTime", default: false)
    static let alertSAGENightTime = UserDefaultsValue<Bool>(key: "alertSAGENightTime", default: false)
    static let alertSAGESnooze = UserDefaultsValue<Int>(key: "alertSAGESnooze", default: 2) //Hours
    static let alertSAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertSAGESnoozedTime", default: nil)
    static let alertSAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertSAGEIsSnoozed", default: false)
    static let alertSAGESound = UserDefaultsValue<String>(key: "alertSAGESound", default: "Wake_Up_Will_You")
    
    static let alertCAGEActive = UserDefaultsValue<Bool>(key: "alertCAGEActive", default: false)
    static let alertCAGE = UserDefaultsValue<Int>(key: "alertCAGE", default: 4) //Hours
    static let alertCAGEQuiet = UserDefaultsValue<Bool>(key: "alertCAGEQuiet", default: false)
    static let alertCAGERepeat = UserDefaultsValue<String>(key: "alertCAGERepeat", default: "Do not repeat")
    static let alertCAGEDayTime = UserDefaultsValue<Bool>(key: "alertCAGEDayTime", default: false)
    static let alertCAGENightTime = UserDefaultsValue<Bool>(key: "alertCAGENightTime", default: false)
    static let alertCAGESnooze = UserDefaultsValue<Int>(key: "alertCAGESnooze", default: 2) //Hours
    static let alertCAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertCAGESnoozedTime", default: nil)
    static let alertCAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertCAGEIsSnoozed", default: false)
    static let alertCAGESound = UserDefaultsValue<String>(key: "alertCAGESound", default: "Wake_Up_Will_You")
    
    static let alertAppInactive = UserDefaultsValue<Bool>(key: "alertAppInactive", default: false)
    
    static let alertTemporaryActive = UserDefaultsValue<Bool>(key: "alertTemporaryActive", default: false)
    static let alertTemporaryBelow = UserDefaultsValue<Bool>(key: "alertTemporaryBelow", default: true)
    static let alertTemporaryBG = UserDefaultsValue<Float>(key: "alertTemporaryBG", default: 90.0)
    static let alertTemporaryBGRepeat = UserDefaultsValue<Bool>(key: "alertTemporaryBGRepeat", default: true)
    static let alertTemporarySound = UserDefaultsValue<String>(key: "alertTemporarySound", default: "Indeed")
    
    static let alertOverrideStart = UserDefaultsValue<Bool>(key: "alertOverrideStart", default: false)
    static let alertOverrideStartQuiet = UserDefaultsValue<Bool>(key: "alertOverrideStartQuiet", default: false)
    static let alertOverrideStartRepeat = UserDefaultsValue<String>(key: "alertOverrideStartRepeat", default: "Do not repeat")
    static let alertOverrideStartDayTime = UserDefaultsValue<Bool>(key: "alertOverrideStartDayTime", default: false)
    static let alertOverrideStartNightTime = UserDefaultsValue<Bool>(key: "alertOverrideStartNightTime", default: false)
    static let alertOverrideStartSound = UserDefaultsValue<String>(key: "alertOverrideStartSound", default: "Ending_Reached")
    static let alertOverrideStartSnoozedTime = UserDefaultsValue<Date?>(key: "alertOverrideStartSnoozedTime", default: nil)
    static let alertOverrideStartIsSnoozed = UserDefaultsValue<Bool>(key: "alertOverrideStartIsSnoozed", default: false)
    
    static let alertOverrideEnd = UserDefaultsValue<Bool>(key: "alertOverrideEnd", default: false)
    static let alertOverrideEndQuiet = UserDefaultsValue<Bool>(key: "alertOverrideEndQuiet", default: false)
    static let alertOverrideEndRepeat = UserDefaultsValue<String>(key: "alertOverrideEndRepeat", default: "Do not repeat")
    static let alertOverrideEndDayTime = UserDefaultsValue<Bool>(key: "alertOverrideEndDayTime", default: false)
    static let alertOverrideEndNightTime = UserDefaultsValue<Bool>(key: "alertOverrideEndNightTime", default: false)
    static let alertOverrideEndSound = UserDefaultsValue<String>(key: "alertOverrideEndSound", default: "Alert_Tone_Busy")
    static let alertOverrideEndSnoozedTime = UserDefaultsValue<Date?>(key: "alertOverrideEndSnoozedTime", default: nil)
    static let alertOverrideEndIsSnoozed = UserDefaultsValue<Bool>(key: "alertOverrideEndIsSnoozed", default: false)
    
    static let alertPump = UserDefaultsValue<Bool>(key: "alertPump", default: false)
    static let alertPumpAt = UserDefaultsValue<Int>(key: "alertPumpAt", default: 10) //Units
    static let alertPumpQuiet = UserDefaultsValue<Bool>(key: "alertPumpQuiet", default: false)
    static let alertPumpRepeat = UserDefaultsValue<String>(key: "alertPumpRepeat", default: "Do not repeat")
    static let alertPumpDayTime = UserDefaultsValue<Bool>(key: "alertPumpDayTime", default: false)
    static let alertPumpNightTime = UserDefaultsValue<Bool>(key: "alertPumpNightTime", default: false)
    static let alertPumpSound = UserDefaultsValue<String>(key: "alertPumpSound", default: "Marimba_Descend")
    static let alertPumpSnoozeHours = UserDefaultsValue<Int>(key: "alertPumpSnoozeHours", default: 5) //Hours
    static let alertPumpIsSnoozed = UserDefaultsValue<Bool>(key: "alertPumpIsSnoozed", default: false)
    static let alertPumpSnoozedTime = UserDefaultsValue<Date?>(key: "alertPumpSnoozedTime", default: nil)
    
}
