// LoopFollow
// Storage.swift

import Foundation
import HealthKit
import UIKit

/*
 Observable persistant storage
 */

class Storage {
    var remoteType = StorageValue<RemoteType>(key: "remoteType", defaultValue: .none)
    var deviceToken = StorageValue<String>(key: "deviceToken", defaultValue: "")
    var expirationDate = StorageValue<Date?>(key: "expirationDate", defaultValue: nil)
    var sharedSecret = StorageValue<String>(key: "sharedSecret", defaultValue: "")
    var productionEnvironment = StorageValue<Bool>(key: "productionEnvironment", defaultValue: false)
    var apnsKey = StorageValue<String>(key: "apnsKey", defaultValue: "")
    var teamId = StorageValue<String?>(key: "teamId", defaultValue: nil)
    var keyId = StorageValue<String>(key: "keyId", defaultValue: "")
    var bundleId = StorageValue<String>(key: "bundleId", defaultValue: "")
    var user = StorageValue<String>(key: "user", defaultValue: "")

    var maxBolus = SecureStorageValue<HKQuantity>(key: "maxBolus", defaultValue: HKQuantity(unit: .internationalUnit(), doubleValue: 1.0))
    var maxCarbs = SecureStorageValue<HKQuantity>(key: "maxCarbs", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxProtein = SecureStorageValue<HKQuantity>(key: "maxProtein", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxFat = SecureStorageValue<HKQuantity>(key: "maxFat", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))

    var mealWithBolus = StorageValue<Bool>(key: "mealWithBolus", defaultValue: false)
    var mealWithFatProtein = StorageValue<Bool>(key: "mealWithFatProtein", defaultValue: false)

    var cachedJWT = StorageValue<String?>(key: "cachedJWT", defaultValue: nil)
    var jwtExpirationDate = StorageValue<Date?>(key: "jwtExpirationDate", defaultValue: nil)

    var backgroundRefreshType = StorageValue<BackgroundRefreshType>(key: "backgroundRefreshType", defaultValue: .silentTune)

    var selectedBLEDevice = StorageValue<BLEDevice?>(key: "selectedBLEDevice", defaultValue: nil)

    var debugLogLevel = StorageValue<Bool>(key: "debugLogLevel", defaultValue: false)

    var contactTrend = StorageValue<ContactIncludeOption>(key: "contactTrend", defaultValue: .off)
    var contactDelta = StorageValue<ContactIncludeOption>(key: "contactDelta", defaultValue: .off)
    var contactEnabled = StorageValue<Bool>(key: "contactEnabled", defaultValue: false)
    var contactBackgroundColor = StorageValue<String>(key: "contactBackgroundColor", defaultValue: ContactColorOption.black.rawValue)
    var contactTextColor = StorageValue<String>(key: "contactTextColor", defaultValue: ContactColorOption.white.rawValue)

    var sensorScheduleOffset = StorageValue<Double?>(key: "sensorScheduleOffset", defaultValue: nil)

    var alarms = StorageValue<[Alarm]>(key: "alarms", defaultValue: [])
    var alarmConfiguration = StorageValue<AlarmConfiguration>(key: "alarmConfiguration", defaultValue: .default)

    var lastOverrideStartNotified = StorageValue<TimeInterval?>(key: "lastOverrideStartNotified", defaultValue: nil)
    var lastOverrideEndNotified = StorageValue<TimeInterval?>(key: "lastOverrideEndNotified", defaultValue: nil)
    var lastTempTargetStartNotified = StorageValue<TimeInterval?>(key: "lastTempTargetStartNotified", defaultValue: nil)
    var lastTempTargetEndNotified = StorageValue<TimeInterval?>(key: "lastTempTargetEndNotified", defaultValue: nil)
    var lastRecBolusNotified = StorageValue<Double?>(key: "lastRecBolusNotified", defaultValue: nil)
    var lastCOBNotified = StorageValue<Double?>(key: "lastCOBNotified", defaultValue: nil)
    var lastMissedBolusNotified = StorageValue<Date?>(key: "lastMissedBolusNotified", defaultValue: nil)

    // General Settings [BEGIN]
    var appBadge = StorageValue<Bool>(key: "appBadge", defaultValue: true)
    var colorBGText = StorageValue<Bool>(key: "colorBGText", defaultValue: true)
    var forceDarkMode = StorageValue<Bool>(key: "forceDarkMode", defaultValue: true)
    var showStats = StorageValue<Bool>(key: "showStats", defaultValue: true)
    var useIFCC = StorageValue<Bool>(key: "useIFCC", defaultValue: false)
    var showSmallGraph = StorageValue<Bool>(key: "showSmallGraph", defaultValue: true)
    var screenlockSwitchState = StorageValue<Bool>(key: "screenlockSwitchState", defaultValue: true)
    var showDisplayName = StorageValue<Bool>(key: "showDisplayName", defaultValue: false)
    var snoozerEmoji = StorageValue<Bool>(key: "snoozerEmoji", defaultValue: false)
    var forcePortraitMode = StorageValue<Bool>(key: "forcePortraitMode", defaultValue: false)

    var speakBG = StorageValue<Bool>(key: "speakBG", defaultValue: false)
    var speakBGAlways = StorageValue<Bool>(key: "speakBGAlways", defaultValue: true)
    var speakLowBG = StorageValue<Bool>(key: "speakLowBG", defaultValue: false)
    var speakProactiveLowBG = StorageValue<Bool>(key: "speakProactiveLowBG", defaultValue: false)
    var speakFastDropDelta = StorageValue<Double>(key: "speakFastDropDelta", defaultValue: 10.0)
    var speakLowBGLimit = StorageValue<Double>(key: "speakLowBGLimit", defaultValue: 72.0)
    var speakHighBGLimit = StorageValue<Double>(key: "speakHighBGLimit", defaultValue: 180.0)
    var speakHighBG = StorageValue<Bool>(key: "speakHighBG", defaultValue: false)
    var speakLanguage = StorageValue<String>(key: "speakLanguage", defaultValue: "en")
    // General Settings [END]

    // Graph Settings [BEGIN]
    var showDots = StorageValue<Bool>(key: "showDots", defaultValue: true)
    var showLines = StorageValue<Bool>(key: "showLines", defaultValue: true)
    var showValues = StorageValue<Bool>(key: "showValues", defaultValue: true)
    var showAbsorption = StorageValue<Bool>(key: "showAbsorption", defaultValue: true)
    var showDIALines = StorageValue<Bool>(key: "showDIAMarkers", defaultValue: true)
    var show30MinLine = StorageValue<Bool>(key: "show30MinLine", defaultValue: false)
    var show90MinLine = StorageValue<Bool>(key: "show90MinLine", defaultValue: false)
    var showMidnightLines = StorageValue<Bool>(key: "showMidnightMarkers", defaultValue: false)
    var smallGraphTreatments = StorageValue<Bool>(key: "smallGraphTreatments", defaultValue: true)

    var smallGraphHeight = StorageValue<Int>(key: "smallGraphHeight", defaultValue: 40)
    var predictionToLoad = StorageValue<Double>(key: "predictionToLoad", defaultValue: 1.0)
    var minBasalScale = StorageValue<Double>(key: "minBasalScale", defaultValue: 5.0)
    var minBGScale = StorageValue<Double>(key: "minBGScale", defaultValue: 250.0)
    var lowLine = StorageValue<Double>(key: "lowLine", defaultValue: 70.0)
    var highLine = StorageValue<Double>(key: "highLine", defaultValue: 180.0)
    var downloadDays = StorageValue<Int>(key: "downloadDays", defaultValue: 1)
    // Graph Settings [END]

    // Calendar entries [BEGIN]
    var writeCalendarEvent = StorageValue<Bool>(key: "writeCalendarEvent", defaultValue: false)
    var calendarIdentifier = StorageValue<String>(key: "calendarIdentifier", defaultValue: "")
    var watchLine1 = StorageValue<String>(key: "watchLine1", defaultValue: "%BG% %DIRECTION% %DELTA% %MINAGO%")
    var watchLine2 = StorageValue<String>(key: "watchLine2", defaultValue: "C:%COB% I:%IOB% B:%BASAL%")
    // Calendar entries [END]

    // MARK: - Dexcom Share --------------------------------------------------------

    var shareUserName = StorageValue<String>(key: "shareUserName", defaultValue: "")
    var sharePassword = StorageValue<String>(key: "sharePassword", defaultValue: "")
    var shareServer = StorageValue<String>(key: "shareServer", defaultValue: "US")

    // MARK: - Graph ---------------------------------------------------------------

    var chartScaleX = StorageValue<Double>(key: "chartScaleX", defaultValue: 18.0)

    // MARK: - Advanced settings ---------------------------------------------------

    var downloadTreatments = StorageValue<Bool>(key: "downloadTreatments", defaultValue: true)
    var downloadPrediction = StorageValue<Bool>(key: "downloadPrediction", defaultValue: true)
    var graphOtherTreatments = StorageValue<Bool>(key: "graphOtherTreatments", defaultValue: true)
    var graphBasal = StorageValue<Bool>(key: "graphBasal", defaultValue: true)
    var graphBolus = StorageValue<Bool>(key: "graphBolus", defaultValue: true)
    var graphCarbs = StorageValue<Bool>(key: "graphCarbs", defaultValue: true)
    var bgUpdateDelay = StorageValue<Int>(key: "bgUpdateDelay", defaultValue: 10)

    // MARK: - Insert times (sensor / pump) ---------------------------------------

    var cageInsertTime = StorageValue<TimeInterval>(key: "cageInsertTime", defaultValue: 0)
    var sageInsertTime = StorageValue<TimeInterval>(key: "sageInsertTime", defaultValue: 0)

    // MARK: - Version-info ---------------------------

    var cachedForVersion = StorageValue<String?>(key: "cachedForVersion", defaultValue: nil)
    var latestVersion = StorageValue<String?>(key: "latestVersion", defaultValue: nil)
    var latestVersionChecked = StorageValue<Date?>(key: "latestVersionChecked", defaultValue: nil)
    var currentVersionBlackListed = StorageValue<Bool>(key: "currentVersionBlackListed", defaultValue: false)
    var lastBlacklistNotificationShown = StorageValue<Date?>(key: "lastBlacklistNotificationShown", defaultValue: nil)
    var lastVersionUpdateNotificationShown = StorageValue<Date?>(key: "lastVersionUpdateNotificationShown", defaultValue: nil)
    var lastExpirationNotificationShown = StorageValue<Date?>(key: "lastExpirationNotificationShown", defaultValue: nil)

    var hideInfoTable = StorageValue<Bool>(key: "hideInfoTable", defaultValue: false)
    var token = StorageValue<String>(key: "token", defaultValue: "")
    var units = StorageValue<String>(key: "units", defaultValue: "mg/dL")

    var infoSort = StorageValue<[Int]>(key: "infoSort", defaultValue: InfoType.allCases.map { $0.sortOrder })
    var infoVisible = StorageValue<[Bool]>(key: "infoVisible", defaultValue: InfoType.allCases.map { $0.defaultVisible })

    var url = StorageValue<String>(key: "url", defaultValue: "")
    var device = StorageValue<String>(key: "device", defaultValue: "")
    var nsWriteAuth = StorageValue<Bool>(key: "nsWriteAuth", defaultValue: false)
    var nsAdminAuth = StorageValue<Bool>(key: "nsAdminAuth", defaultValue: false)

    var migrationStep = StorageValue<Int>(key: "migrationStep", defaultValue: 0)

    var persistentNotification = StorageValue<Bool>(key: "persistentNotification", defaultValue: false)
    var persistentNotificationLastBGTime = StorageValue<Date>(key: "persistentNotificationLastBGTime", defaultValue: .distantPast)

    var lastLoopingChecked = StorageValue<Date?>(key: "lastLoopingChecked", defaultValue: nil)

    var alarmsPosition = StorageValue<TabPosition>(key: "alarmsPosition", defaultValue: .position2)
    var remotePosition = StorageValue<TabPosition>(key: "remotePosition", defaultValue: .more)
    var nightscoutPosition = StorageValue<TabPosition>(key: "nightscoutPosition", defaultValue: .position4)

    var loopAPNSQrCodeURL = StorageValue<String>(key: "loopAPNSQrCodeURL", defaultValue: "")

    var returnApnsKey = StorageValue<String>(key: "returnApnsKey", defaultValue: "")
    var returnKeyId = StorageValue<String>(key: "returnKeyId", defaultValue: "")

    static let shared = Storage()
    private init() {}
}
