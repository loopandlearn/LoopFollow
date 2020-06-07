//
//  UserDefaults.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/4/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation

class UserDefaultsRepository {
    
    //Nightscout Settings
    static let url = UserDefaultsValue<String>(key: "url", default: "")
    static let token = UserDefaultsValue<String>(key: "token", default: "")
    
    // Graph Settings
    static let showDots = UserDefaultsValue<Bool>(key: "showDots", default: true)
    static let showLines = UserDefaultsValue<Bool>(key: "showLines", default: true)
    static let hoursToLoad = UserDefaultsValue<Int>(key: "hoursToLoad", default: 24)
    
    // General Settings
    static let backgroundRefreshFrequency = UserDefaultsValue<Int>(key: "backgroundRefreshFrequency", default: 1)
    static let backgroundRefresh = UserDefaultsValue<Bool>(key: "backgroundRefresh", default: true)
    static let appBadge = UserDefaultsValue<Bool>(key: "appBadge", default: true)
    
    // Alerts
    static let alertUrgentLowActive = UserDefaultsValue<Bool>(key: "alertUrgentLowActive", default: true)
    static let alertUrgentLow = UserDefaultsValue<Int>(key: "alertUrgentLow", default: 55)
    static let alertUrgentLowSnooze = UserDefaultsValue<Int>(key: "alertUrgentLowSnooze", default: 5)
    static let alertUrgentLowSnoozedTime = UserDefaultsValue<Date>(key: "alertUrgentLowSnoozedTime", default: Date())
    
    static let alertLowActive = UserDefaultsValue<Bool>(key: "alertLowActive", default: true)
    static let alertLow = UserDefaultsValue<Int>(key: "alertLow", default: 70)
    static let alertLowSnooze = UserDefaultsValue<Int>(key: "alertLowSnooze", default: 5)
    static let alertLowSnoozedTime = UserDefaultsValue<Date>(key: "alertLowSnoozedTime", default: Date())
    
    static let alertHighActive = UserDefaultsValue<Bool>(key: "alertHighActive", default: true)
    static let alertHigh = UserDefaultsValue<Int>(key: "alertHigh", default: 180)
    static let alertHighPersistent = UserDefaultsValue<Int>(key: "alertHighPersistent", default: 60)
    static let alertHighSnooze = UserDefaultsValue<Int>(key: "alertHighSnooze", default: 60)
    static let alertHighSnoozedTime = UserDefaultsValue<Date>(key: "alertHighSnoozedTime", default: Date())
    
    static let alertUrgentHighActive = UserDefaultsValue<Bool>(key: "alertUrgentHighActive", default: true)
    static let alertUrgentHigh = UserDefaultsValue<Int>(key: "alertUrgentHigh", default: 250)
    static let alertUrgentHighSnooze = UserDefaultsValue<Int>(key: "alertUrgentHighSnooze", default: 30)
    static let alertUrgentHighSnoozedTime = UserDefaultsValue<Date>(key: "alertUrgentHighSnoozedTime", default: Date())
    
    static let alertFastActive = UserDefaultsValue<Bool>(key: "alertFastDeltaActive", default: true)
    static let alertFastSnooze = UserDefaultsValue<Int>(key: "alertFastDeltaSnooze", default: 10)
    static let alertFastDelta = UserDefaultsValue<Int>(key: "alertFastDelta", default: 10)
    static let alertFastReadings = UserDefaultsValue<Int>(key: "alertFastReadings", default: 3)
    static let alertFastUseLimits = UserDefaultsValue<Bool>(key: "alertFastUseLimits", default: true)
    static let alertFastLowerLimit = UserDefaultsValue<Int>(key: "alertFastBelowBG", default: 110)
    static let alertFastUpperLimit = UserDefaultsValue<Int>(key: "alertFastAboveBG", default: 200)
    static let alertFastSnoozedTime = UserDefaultsValue<Date>(key: "alertFastSnoozedTime", default: Date())
    
    static let alertMissedReadingActive = UserDefaultsValue<Bool>(key: "alertMissedReadingActive", default: true)
    static let alertMissedReading = UserDefaultsValue<Int>(key: "alertMissedReading", default: 30)
    static let alertMissedReadingSnooze = UserDefaultsValue<Int>(key: "alertMissedReadingSnooze", default: 30)
    static let alertMissedReadingsSnoozedTime = UserDefaultsValue<Date>(key: "alertMissedReadingsSnoozedTime", default: Date())
    
    
    static let alertNotLoopingActive = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: true)
    static let alertNotLooping = UserDefaultsValue<Int>(key: "alertNotLooping", default: 30)
    static let alertNotLoopingSnooze = UserDefaultsValue<Int>(key: "alertNotLoopingSnooze", default: 30)
    static let alertNotLoopingUseLimits = UserDefaultsValue<Bool>(key: "alertNotLoopingUseLimits", default: true)
    static let alertNotLoopingLowerLimit = UserDefaultsValue<Int>(key: "alertNotLoopingBelowBG", default: 100)
    static let alertNotLoopingUpperLimit = UserDefaultsValue<Int>(key: "alertNotLoopingAboveBG", default: 160)
    static let alertNotLoopingSnoozedTime = UserDefaultsValue<Date>(key: "alertNotLoopingSnoozedTime", default: Date())
    
    static let alertMissedBolusActive = UserDefaultsValue<Bool>(key: "alertMissedBolusActive", default: true)
    static let alertMissedBolus = UserDefaultsValue<Int>(key: "alertMissedBolus", default: 10)
    static let alertMissedBolusSnooze = UserDefaultsValue<Int>(key: "alertMissedBolusSnooze", default: 10)
    static let alertMissedBolusLowGramsActive = UserDefaultsValue<Bool>(key: "alertMissedBolusLowGramsActive", default: true)
    static let alertMissedBolusLowGrams = UserDefaultsValue<Int>(key: "alertMissedBolusLowGrams", default: 10)
    static let alertMissedBolusLowGramsBG = UserDefaultsValue<Int>(key: "alertMissedBolusLowGramsBG", default: 70)
    static let alertMissedBolusSnoozedTime = UserDefaultsValue<Date>(key: "alertMissedBolusSnoozedTime", default: Date())
    
    static let alertSAGEActive = UserDefaultsValue<Bool>(key: "alertSAGEActive", default: true)
    static let alertSAGE = UserDefaultsValue<Int>(key: "alertSAGE", default: 8) //Hours
    static let alertSAGESnooze = UserDefaultsValue<Int>(key: "alertSAGESnooze", default: 2) //Hours
    static let alertSAGESnoozedTime = UserDefaultsValue<Date>(key: "alertSAGESnoozedTime", default: Date())
    
    static let alertCAGEActive = UserDefaultsValue<Bool>(key: "alertCAGEActive", default: true)
    static let alertCAGE = UserDefaultsValue<Int>(key: "alertCAGE", default: 4) //Hours
    static let alertCAGESnooze = UserDefaultsValue<Int>(key: "alertCAGESnooze", default: 2) //Hours
    static let alertCAGEnoozedTime = UserDefaultsValue<Date>(key: "alertCAGESnoozedTime", default: Date())
    
    static let alertAppInactive = UserDefaultsValue<Bool>(key: "alertAppInactive", default: true)
    
    static let alertTemporaryActive = UserDefaultsValue<Bool>(key: "alertTemporaryActive", default: false)
    static let alertTemporaryBelow = UserDefaultsValue<Bool>(key: "alertTemporaryBelow", default: true)
    static let alertTemporary = UserDefaultsValue<Int>(key: "alertTemporary", default: 90)
}
