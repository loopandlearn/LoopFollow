// LoopFollow
// Observable.swift

import Foundation
import HealthKit
import SwiftUI

/*
 Observable in memory storage
 */

class Observable {
    static let shared = Observable()

    var tempTarget = ObservableValue<HKQuantity?>(default: nil)
    var override = ObservableValue<String?>(default: nil)

    /// End of the active override as Unix epoch seconds; nil = no override or indefinite.
    var overrideEndAt = ObservableValue<TimeInterval?>(default: nil)
    /// End of the active temp target as Unix epoch seconds; nil = no active temp target.
    var tempTargetEndAt = ObservableValue<TimeInterval?>(default: nil)

    var minAgoText = ObservableValue<String>(default: "?? min ago")
    var bgText = ObservableValue<String>(default: "BG")
    var bg = ObservableValue<Int?>(default: nil)
    var bgStale = ObservableValue<Bool>(default: true)
    var bgTextColor = ObservableValue<Color>(default: .primary)
    var directionText = ObservableValue<String>(default: "-")
    var deltaText = ObservableValue<String>(default: "+0")
    var iobText = ObservableValue<String>(default: "--")

    var serverText = ObservableValue<String>(default: "Server")
    var loopStatusText = ObservableValue<String>(default: "")
    var loopStatusColor = ObservableValue<Color>(default: .primary)
    var predictionText = ObservableValue<String>(default: "")
    var predictionColor = ObservableValue<Color>(default: .purple)

    var currentAlarm = ObservableValue<UUID?>(default: nil)
    var alarmSoundPlaying = ObservableValue<Bool>(default: false)

    var debug = ObservableValue<Bool>(default: false)

    var chartSettingsChanged = ObservableValue<Bool>(default: false)

    var alertLastLoopTime = ObservableValue<TimeInterval?>(default: nil)
    var previousAlertLastLoopTime = ObservableValue<TimeInterval?>(default: nil)
    var deviceRecBolus = ObservableValue<Double?>(default: nil)
    var deviceBatteryLevel = ObservableValue<Double?>(default: nil)
    var deviceBatteryIsCharging = ObservableValue<Bool?>(default: nil)
    var pumpBatteryLevel = ObservableValue<Double?>(default: nil)
    var dbSizePercentage = ObservableValue<Double?>(default: nil)
    var enactedOrSuggested = ObservableValue<TimeInterval?>(default: nil)

    var lastSentTOTP = ObservableValue<String?>(default: nil)

    var loopFollowDeviceToken = ObservableValue<String>(default: "")

    var isNotLooping = ObservableValue<Bool>(default: false)

    /// Selected tab index used by SwiftUI TabView — set from MainViewController to switch tabs
    var selectedTabIndex = ObservableValue<Int>(default: 0)

    /// Currently visible app-wide banner (nil = hidden). Managed by BannerManager.
    var activeBanner = ObservableValue<BannerMessage?>(default: nil)

    /// True while the onboarding cover is on screen; AlarmManager doesn't act
    /// on alarms while set. In-memory, so background launches are unaffected.
    var isOnboardingActive = ObservableValue<Bool>(default: false)

    private init() {}
}
