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
    
    // Alarm Settings
    
    // Alerts
    static let alertUrgentLowActive = UserDefaultsValue<Bool>(key: "alertUrgentLowActive", default: true)
    static let alertUrgentLowBG = UserDefaultsValue<Int>(key: "alertUrgentLowBG", default: 55)
    static let alertUrgentLowSnooze = UserDefaultsValue<Int>(key: "alertUrgentLowSnooze", default: 5)
    static let alertUrgentLowSnoozedTime = UserDefaultsValue<Date?>(key: "alertUrgentLowSnoozedTime", default: nil)
    static let alertUrgentLowIsSnoozed = UserDefaultsValue<Bool>(key: "alertUrgentLowIsSnoozed", default: false)
    
    static let alertLowActive = UserDefaultsValue<Bool>(key: "alertLowActive", default: true)
    static let alertLowBG = UserDefaultsValue<Int>(key: "alertLowBG", default: 70)
    static let alertLowSnooze = UserDefaultsValue<Int>(key: "alertLowSnooze", default: 5)
    static let alertLowSnoozedTime = UserDefaultsValue<Date?>(key: "alertLowSnoozedTime", default: nil)
    static let alertLowIsSnoozed = UserDefaultsValue<Bool>(key: "alertLowIsSnoozed", default: false)
    
    static let alertHighActive = UserDefaultsValue<Bool>(key: "alertHighActive", default: true)
    static let alertHighBG = UserDefaultsValue<Int>(key: "alertHighBG", default: 180)
    static let alertHighPersistent = UserDefaultsValue<Int>(key: "alertHighPersistent", default: 60)
    static let alertHighSnooze = UserDefaultsValue<Int>(key: "alertHighSnooze", default: 60)
    static let alertHighSnoozedTime = UserDefaultsValue<Date?>(key: "alertHighSnoozedTime", default: nil)
    static let alertHighIsSnoozed = UserDefaultsValue<Bool>(key: "alertHighIsSnoozed", default: false)
    
    static let alertUrgentHighActive = UserDefaultsValue<Bool>(key: "alertUrgentHighActive", default: true)
    static let alertUrgentHighBG = UserDefaultsValue<Int>(key: "alertUrgentHighBG", default: 250)
    static let alertUrgentHighSnooze = UserDefaultsValue<Int>(key: "alertUrgentHighSnooze", default: 30)
    static let alertUrgentHighSnoozedTime = UserDefaultsValue<Date?>(key: "alertUrgentHighSnoozedTime", default: nil)
    static let alertUrgentHighIsSnoozed = UserDefaultsValue<Bool>(key: "alertUrgentHighIsSnoozed", default: false)

    
    static let alertFastDropActive = UserDefaultsValue<Bool>(key: "alertFastDropDeltaActive", default: true)
    static let alertFastDropSnooze = UserDefaultsValue<Int>(key: "alertFastDropDeltaSnooze", default: 10)
    static let alertFastDropDelta = UserDefaultsValue<Int>(key: "alertFastDropDelta", default: 10)
    static let alertFastDropReadings = UserDefaultsValue<Int>(key: "alertFastDropReadings", default: 3)
    static let alertFastDropUseLimit = UserDefaultsValue<Bool>(key: "alertFastDropUseLimit", default: true)
    static let alertFastDropBelowBG = UserDefaultsValue<Int>(key: "alertFastDropBelowBG", default: 120)
    static let alertFastDropSnoozedTime = UserDefaultsValue<Date?>(key: "alertFastDropSnoozedTime", default: nil)
    static let alertFastDropIsSnoozed = UserDefaultsValue<Bool>(key: "alertFastDropIsSnoozed", default: false)
    
    static let alertFastRiseActive = UserDefaultsValue<Bool>(key: "alertFastRiseDeltaActive", default: true)
    static let alertFastRiseSnooze = UserDefaultsValue<Int>(key: "alertFastRiseDeltaSnooze", default: 10)
    static let alertFastRiseDelta = UserDefaultsValue<Int>(key: "alertFastRiseDelta", default: 10)
    static let alertFastRiseReadings = UserDefaultsValue<Int>(key: "alertFastRiseReadings", default: 3)
    static let alertFastRiseUseLimit = UserDefaultsValue<Bool>(key: "alertFastRiseUseLimit", default: true)
    static let alertFastRiseAboveBG = UserDefaultsValue<Int>(key: "alertFastRiseAboveBG", default: 200)
    static let alertFastRiseSnoozedTime = UserDefaultsValue<Date?>(key: "alertFastRiseSnoozedTime", default: nil)
    static let alertFastRiseIsSnoozed = UserDefaultsValue<Bool>(key: "alertFastRiseIsSnoozed", default: false)
    
    
    static let alertMissedReadingActive = UserDefaultsValue<Bool>(key: "alertMissedReadingActive", default: true)
    static let alertMissedReading = UserDefaultsValue<Int>(key: "alertMissedReading", default: 30)
    static let alertMissedReadingSnooze = UserDefaultsValue<Int>(key: "alertMissedReadingSnooze", default: 30)
    static let alertMissedReadingSnoozedTime = UserDefaultsValue<Date?>(key: "alertMissedReadingSnoozedTime", default: nil)
    static let alertMissedReadingIsSnoozed = UserDefaultsValue<Bool>(key: "alertMissedReadingIsSnoozed", default: false)
    
    
    static let alertNotLoopingActive = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: true)
    static let alertNotLooping = UserDefaultsValue<Int>(key: "alertNotLooping", default: 30)
    static let alertNotLoopingSnooze = UserDefaultsValue<Int>(key: "alertNotLoopingSnooze", default: 30)
    static let alertNotLoopingUseLimits = UserDefaultsValue<Bool>(key: "alertNotLoopingUseLimits", default: true)
    static let alertNotLoopingLowerLimit = UserDefaultsValue<Int>(key: "alertNotLoopingBelowBG", default: 100)
    static let alertNotLoopingUpperLimit = UserDefaultsValue<Int>(key: "alertNotLoopingAboveBG", default: 160)
    static let alertNotLoopingSnoozedTime = UserDefaultsValue<Date?>(key: "alertNotLoopingSnoozedTime", default: nil)
    static let alertNotLoopingIsSnoozed = UserDefaultsValue<Bool>(key: "alertNotLoopingIsSnoozed", default: false)
    
    static let alertMissedBolusActive = UserDefaultsValue<Bool>(key: "alertMissedBolusActive", default: true)
    static let alertMissedBolus = UserDefaultsValue<Int>(key: "alertMissedBolus", default: 10)
    static let alertMissedBolusSnooze = UserDefaultsValue<Int>(key: "alertMissedBolusSnooze", default: 10)
    static let alertMissedBolusLowGramsActive = UserDefaultsValue<Bool>(key: "alertMissedBolusLowGramsActive", default: true)
    static let alertMissedBolusLowGrams = UserDefaultsValue<Int>(key: "alertMissedBolusLowGrams", default: 10)
    static let alertMissedBolusLowGramsBG = UserDefaultsValue<Int>(key: "alertMissedBolusLowGramsBG", default: 70)
    static let alertMissedBolusSnoozedTime = UserDefaultsValue<Date?>(key: "alertMissedBolusSnoozedTime", default: nil)
    static let alertMissedBolusIsSnoozed = UserDefaultsValue<Bool>(key: "alertMissedBolusIsSnoozed", default: false)
    
    static let alertSAGEActive = UserDefaultsValue<Bool>(key: "alertSAGEActive", default: true)
    static let alertSAGE = UserDefaultsValue<Int>(key: "alertSAGE", default: 8) //Hours
    static let alertSAGESnooze = UserDefaultsValue<Int>(key: "alertSAGESnooze", default: 2) //Hours
    static let alertSAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertSAGESnoozedTime", default: nil)
    static let alertSAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertSAGEIsSnoozed", default: false)
    
    static let alertCAGEActive = UserDefaultsValue<Bool>(key: "alertCAGEActive", default: true)
    static let alertCAGE = UserDefaultsValue<Int>(key: "alertCAGE", default: 4) //Hours
    static let alertCAGESnooze = UserDefaultsValue<Int>(key: "alertCAGESnooze", default: 2) //Hours
    static let alertCAGESnoozedTime = UserDefaultsValue<Date?>(key: "alertCAGESnoozedTime", default: nil)
    static let alertCAGEIsSnoozed = UserDefaultsValue<Bool>(key: "alertCAGEIsSnoozed", default: false)
    
    static let alertAppInactive = UserDefaultsValue<Bool>(key: "alertAppInactive", default: true)
    
    static let alertTemporaryActive = UserDefaultsValue<Bool>(key: "alertTemporaryActive", default: false)
    static let alertTemporaryBelow = UserDefaultsValue<Bool>(key: "alertTemporaryBelow", default: true)
    static let alertTemporaryBG = UserDefaultsValue<Int>(key: "alertTemporaryBG", default: 90)
}
