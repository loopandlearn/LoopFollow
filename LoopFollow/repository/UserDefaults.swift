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
    
    static let alertLowActive = UserDefaultsValue<Bool>(key: "alertLowActive", default: true)
    static let alertLow = UserDefaultsValue<Int>(key: "alertLow", default: 70)
    static let alertLowSnooze = UserDefaultsValue<Int>(key: "alertLowSnooze", default: 5)
    
    static let alertHighActive = UserDefaultsValue<Bool>(key: "alertHighActive", default: true)
    static let alertHigh = UserDefaultsValue<Int>(key: "alerthigh", default: 180)
    static let alertHighSnooze = UserDefaultsValue<Int>(key: "alerthigh", default: 60)
    
    static let alertUrgentHighActive = UserDefaultsValue<Bool>(key: "alertUrgentHighActive", default: true)
    static let alertUrgentHigh = UserDefaultsValue<Int>(key: "alertUrgentHigh", default: 250)
    static let alertUrgentHighSnooze = UserDefaultsValue<Int>(key: "alertUrgentHighSnooze", default: 30)
    
    static let alertFastActive = UserDefaultsValue<Bool>(key: "alertFastDeltaActive", default: true)
    static let alertFastSnooze = UserDefaultsValue<Int>(key: "alertFastDeltaSnooze", default: 10)
    static let alertFastDelta = UserDefaultsValue<Int>(key: "alertFastDelta", default: 10)
    static let alertFastLowerLimit = UserDefaultsValue<Int>(key: "alertFastLowerLimit", default: 110)
    static let alertFastUpperLimit = UserDefaultsValue<Int>(key: "alertFastUpperLimit", default: 200)
    
    static let alertMissedReadingActive = UserDefaultsValue<Bool>(key: "alertMissedReadingActive", default: true)
    static let alertMissedReading = UserDefaultsValue<Int>(key: "alertMissedReading", default: 30)
    static let alertMissedReadingSnooze = UserDefaultsValue<Int>(key: "alertMissedReadingSnooze", default: 30)
    
    static let alertNotLoopingActive = UserDefaultsValue<Bool>(key: "alertNotLoopingActive", default: true)
    static let alertNotLooping = UserDefaultsValue<Int>(key: "alertNotLooping", default: 30)
    static let alertNotLoopingSnooze = UserDefaultsValue<Int>(key: "alertNotLoopingSnooze", default: 30)
}
