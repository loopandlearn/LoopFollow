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
    var remoteApnsKey = StorageValue<String>(key: "remoteApnsKey", defaultValue: "")
    var teamId = StorageValue<String?>(key: "teamId", defaultValue: nil)
    var remoteKeyId = StorageValue<String>(key: "remoteKeyId", defaultValue: "")

    var lfApnsKey = StorageValue<String>(key: "lfApnsKey", defaultValue: "")
    var lfKeyId = StorageValue<String>(key: "lfKeyId", defaultValue: "")
    var bundleId = StorageValue<String>(key: "bundleId", defaultValue: "")
    var user = StorageValue<String>(key: "user", defaultValue: "")

    var maxBolus = SecureStorageValue<HKQuantity>(key: "maxBolus", defaultValue: HKQuantity(unit: .internationalUnit(), doubleValue: 1.0))
    var maxCarbs = SecureStorageValue<HKQuantity>(key: "maxCarbs", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxProtein = SecureStorageValue<HKQuantity>(key: "maxProtein", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))
    var maxFat = SecureStorageValue<HKQuantity>(key: "maxFat", defaultValue: HKQuantity(unit: .gram(), doubleValue: 30.0))

    var mealWithBolus = StorageValue<Bool>(key: "mealWithBolus", defaultValue: false)
    var mealWithFatProtein = StorageValue<Bool>(key: "mealWithFatProtein", defaultValue: false)

    // TODO: This flag can be deleted in March 2027. Check the commit for other places to cleanup.
    var hasSeenFatProteinOrderChange = StorageValue<Bool>(key: "hasSeenFatProteinOrderChange", defaultValue: false)

    var backgroundRefreshType = StorageValue<BackgroundRefreshType>(key: "backgroundRefreshType", defaultValue: .silentTune)

    var selectedBLEDevice = StorageValue<BLEDevice?>(key: "selectedBLEDevice", defaultValue: nil)

    var debugLogLevel = StorageValue<Bool>(key: "debugLogLevel", defaultValue: false)

    var contactTrend = StorageValue<ContactIncludeOption>(key: "contactTrend", defaultValue: .off)
    var contactDelta = StorageValue<ContactIncludeOption>(key: "contactDelta", defaultValue: .off)
    var contactIOB = StorageValue<ContactIncludeOption>(key: "contactIOB", defaultValue: .off)
    var contactTrendTarget = StorageValue<ContactType>(key: "contactTrendTarget", defaultValue: .BG)
    var contactDeltaTarget = StorageValue<ContactType>(key: "contactDeltaTarget", defaultValue: .BG)
    var contactIOBTarget = StorageValue<ContactType>(key: "contactIOBTarget", defaultValue: .BG)
    var contactEnabled = StorageValue<Bool>(key: "contactEnabled", defaultValue: false)
    var contactBackgroundColor = StorageValue<String>(key: "contactBackgroundColor", defaultValue: ContactColorOption.black.rawValue)
    var contactTextColor = StorageValue<String>(key: "contactTextColor", defaultValue: ContactColorOption.white.rawValue)
    var contactColorMode = StorageValue<ContactColorMode>(key: "contactColorMode", defaultValue: .staticColor)

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
    var pendingFutureCarbs = StorageValue<[PendingFutureCarb]>(key: "pendingFutureCarbs", defaultValue: [])

    // General Settings [BEGIN]
    var appBadge = StorageValue<Bool>(key: "appBadge", defaultValue: true)
    var colorBGText = StorageValue<Bool>(key: "colorBGText", defaultValue: true)
    var appearanceMode = StorageValue<AppearanceMode>(key: "appearanceMode", defaultValue: .dark)
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

    // Live Activity glucose state
    var lastBgReadingTimeSeconds = StorageValue<TimeInterval?>(key: "lastBgReadingTimeSeconds", defaultValue: nil)
    var lastDeltaMgdl = StorageValue<Double?>(key: "lastDeltaMgdl", defaultValue: nil)
    var lastTrendCode = StorageValue<String?>(key: "lastTrendCode", defaultValue: nil)
    var lastIOB = StorageValue<Double?>(key: "lastIOB", defaultValue: nil)
    var lastCOB = StorageValue<Double?>(key: "lastCOB", defaultValue: nil)
    var projectedBgMgdl = StorageValue<Double?>(key: "projectedBgMgdl", defaultValue: nil)

    // Live Activity extended InfoType data
    var lastBasal = StorageValue<String>(key: "lastBasal", defaultValue: "")
    var lastPumpReservoirU = StorageValue<Double?>(key: "lastPumpReservoirU", defaultValue: nil)
    var lastAutosens = StorageValue<Double?>(key: "lastAutosens", defaultValue: nil)
    var lastTdd = StorageValue<Double?>(key: "lastTdd", defaultValue: nil)
    var lastTargetLowMgdl = StorageValue<Double?>(key: "lastTargetLowMgdl", defaultValue: nil)
    var lastTargetHighMgdl = StorageValue<Double?>(key: "lastTargetHighMgdl", defaultValue: nil)
    var lastIsfMgdlPerU = StorageValue<Double?>(key: "lastIsfMgdlPerU", defaultValue: nil)
    var lastCarbRatio = StorageValue<Double?>(key: "lastCarbRatio", defaultValue: nil)
    var lastCarbsToday = StorageValue<Double?>(key: "lastCarbsToday", defaultValue: nil)
    var lastProfileName = StorageValue<String>(key: "lastProfileName", defaultValue: "")
    var iageInsertTime = StorageValue<TimeInterval>(key: "iageInsertTime", defaultValue: 0)
    var lastMinBgMgdl = StorageValue<Double?>(key: "lastMinBgMgdl", defaultValue: nil)
    var lastMaxBgMgdl = StorageValue<Double?>(key: "lastMaxBgMgdl", defaultValue: nil)

    // Live Activity
    var laEnabled = StorageValue<Bool>(key: "laEnabled", defaultValue: false)
    var laRenewBy = StorageValue<TimeInterval>(key: "laRenewBy", defaultValue: 0)
    var laRenewalFailed = StorageValue<Bool>(key: "laRenewalFailed", defaultValue: false)

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
    var graphTimeZoneEnabled = StorageValue<Bool>(key: "graphTimeZoneEnabled", defaultValue: false)
    var graphTimeZoneIdentifier = StorageValue<String>(key: "graphTimeZoneIdentifier", defaultValue: TimeZone.current.identifier)
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

    var infoSort = StorageValue<[Int]>(key: "infoSort", defaultValue: InfoType.allCases.map(\.sortOrder))
    var infoVisible = StorageValue<[Bool]>(key: "infoVisible", defaultValue: InfoType.allCases.map(\.defaultVisible))

    var url = StorageValue<String>(key: "url", defaultValue: "")
    var device = StorageValue<String>(key: "device", defaultValue: "")
    var nsWriteAuth = StorageValue<Bool>(key: "nsWriteAuth", defaultValue: false)
    var nsAdminAuth = StorageValue<Bool>(key: "nsAdminAuth", defaultValue: false)

    var migrationStep = StorageValue<Int>(key: "migrationStep", defaultValue: 0)

    var persistentNotification = StorageValue<Bool>(key: "persistentNotification", defaultValue: false)
    var persistentNotificationLastBGTime = StorageValue<Date>(key: "persistentNotificationLastBGTime", defaultValue: .distantPast)

    var lastLoopingChecked = StorageValue<Date?>(key: "lastLoopingChecked", defaultValue: nil)
    var lastBGChecked = StorageValue<Date?>(key: "lastBGChecked", defaultValue: nil)
    var lastLoopTime = StorageValue<TimeInterval>(key: "lastLoopTime", defaultValue: 0)

    // Tab positions - which position each item is in (positions 1-4 are customizable, 5 is always Menu)
    var homePosition = StorageValue<TabPosition>(key: "homePosition", defaultValue: .position1)
    var alarmsPosition = StorageValue<TabPosition>(key: "alarmsPosition", defaultValue: .position2)
    var snoozerPosition = StorageValue<TabPosition>(key: "snoozerPosition", defaultValue: .menu)
    var nightscoutPosition = StorageValue<TabPosition>(key: "nightscoutPosition", defaultValue: .position3)
    var remotePosition = StorageValue<TabPosition>(key: "remotePosition", defaultValue: .position4)
    var statisticsPosition = StorageValue<TabPosition>(key: "statisticsPosition", defaultValue: .menu)
    var treatmentsPosition = StorageValue<TabPosition>(key: "treatmentsPosition", defaultValue: .menu)

    var loopAPNSQrCodeURL = StorageValue<String>(key: "loopAPNSQrCodeURL", defaultValue: "")

    var bolusIncrement = SecureStorageValue<HKQuantity>(key: "bolusIncrement", defaultValue: HKQuantity(unit: .internationalUnit(), doubleValue: 0.05))
    var bolusIncrementDetected = StorageValue<Bool>(key: "bolusIncrementDetected", defaultValue: false)
    // Statistics display preferences
    var showGMI = StorageValue<Bool>(key: "showGMI", defaultValue: true)
    var showStdDev = StorageValue<Bool>(key: "showStdDev", defaultValue: true)
    var showTITR = StorageValue<Bool>(key: "showTITR", defaultValue: false)

    static let shared = Storage()
    private init() {}

    /// Set to true at launch if isProtectedDataAvailable was false (BFU state).
    /// Consumed and cleared on the first foreground after that launch.
    var needsBFUReload = false

    /// Re-reads every StorageValue from UserDefaults, firing @Published only where the value
    /// actually changed. Call this when foregrounding after a Before-First-Unlock (BFU) background
    /// launch, where Storage was initialized while UserDefaults was encrypted and all values were
    /// cached as their defaults.
    ///
    /// `migrationStep` is intentionally excluded: viewDidLoad writes it to 6 during the BFU
    /// launch; if we reloaded it and the flush had somehow not landed yet, migrations would re-run.
    ///
    /// SecureStorageValue properties (maxBolus, maxCarbs, maxProtein, maxFat, bolusIncrement) are
    /// not covered here — SecureStorageValue does not implement reload() and Keychain has the same
    /// BFU inaccessibility; that is a separate problem.
    func reloadAll() {
        remoteType.reload()
        deviceToken.reload()
        expirationDate.reload()
        sharedSecret.reload()
        productionEnvironment.reload()
        remoteApnsKey.reload()
        teamId.reload()
        remoteKeyId.reload()

        lfApnsKey.reload()
        lfKeyId.reload()
        bundleId.reload()
        user.reload()

        mealWithBolus.reload()
        mealWithFatProtein.reload()
        hasSeenFatProteinOrderChange.reload()

        backgroundRefreshType.reload()
        selectedBLEDevice.reload()
        debugLogLevel.reload()

        contactTrend.reload()
        contactDelta.reload()
        contactEnabled.reload()
        contactBackgroundColor.reload()
        contactTextColor.reload()

        sensorScheduleOffset.reload()
        alarms.reload()
        alarmConfiguration.reload()

        lastOverrideStartNotified.reload()
        lastOverrideEndNotified.reload()
        lastTempTargetStartNotified.reload()
        lastTempTargetEndNotified.reload()
        lastRecBolusNotified.reload()
        lastCOBNotified.reload()
        lastMissedBolusNotified.reload()

        appBadge.reload()
        colorBGText.reload()
        appearanceMode.reload()
        showStats.reload()
        useIFCC.reload()
        showSmallGraph.reload()
        screenlockSwitchState.reload()
        showDisplayName.reload()
        snoozerEmoji.reload()
        forcePortraitMode.reload()

        speakBG.reload()
        speakBGAlways.reload()
        speakLowBG.reload()
        speakProactiveLowBG.reload()
        speakFastDropDelta.reload()
        speakLowBGLimit.reload()
        speakHighBGLimit.reload()
        speakHighBG.reload()
        speakLanguage.reload()

        lastBgReadingTimeSeconds.reload()
        lastDeltaMgdl.reload()
        lastTrendCode.reload()
        lastIOB.reload()
        lastCOB.reload()
        projectedBgMgdl.reload()

        lastBasal.reload()
        lastPumpReservoirU.reload()
        lastAutosens.reload()
        lastTdd.reload()
        lastTargetLowMgdl.reload()
        lastTargetHighMgdl.reload()
        lastIsfMgdlPerU.reload()
        lastCarbRatio.reload()
        lastCarbsToday.reload()
        lastProfileName.reload()
        iageInsertTime.reload()
        lastMinBgMgdl.reload()
        lastMaxBgMgdl.reload()

        laEnabled.reload()
        laRenewBy.reload()
        laRenewalFailed.reload()

        showDots.reload()
        showLines.reload()
        showValues.reload()
        showAbsorption.reload()
        showDIALines.reload()
        show30MinLine.reload()
        show90MinLine.reload()
        showMidnightLines.reload()
        smallGraphTreatments.reload()
        smallGraphHeight.reload()
        predictionToLoad.reload()
        minBasalScale.reload()
        minBGScale.reload()
        lowLine.reload()
        highLine.reload()
        downloadDays.reload()
        graphTimeZoneEnabled.reload()
        graphTimeZoneIdentifier.reload()

        writeCalendarEvent.reload()
        calendarIdentifier.reload()
        watchLine1.reload()
        watchLine2.reload()

        shareUserName.reload()
        sharePassword.reload()
        shareServer.reload()

        chartScaleX.reload()

        downloadTreatments.reload()
        downloadPrediction.reload()
        graphOtherTreatments.reload()
        graphBasal.reload()
        graphBolus.reload()
        graphCarbs.reload()
        bgUpdateDelay.reload()

        cageInsertTime.reload()
        sageInsertTime.reload()

        cachedForVersion.reload()
        latestVersion.reload()
        latestVersionChecked.reload()
        currentVersionBlackListed.reload()
        lastBlacklistNotificationShown.reload()
        lastVersionUpdateNotificationShown.reload()
        lastExpirationNotificationShown.reload()

        hideInfoTable.reload()
        token.reload()
        units.reload()
        infoSort.reload()
        infoVisible.reload()

        url.reload()
        device.reload()
        nsWriteAuth.reload()
        nsAdminAuth.reload()

        // migrationStep intentionally excluded — see method comment above.

        persistentNotification.reload()
        persistentNotificationLastBGTime.reload()

        lastLoopingChecked.reload()
        lastBGChecked.reload()
        lastLoopTime.reload()

        homePosition.reload()
        alarmsPosition.reload()
        snoozerPosition.reload()
        nightscoutPosition.reload()
        remotePosition.reload()
        statisticsPosition.reload()
        treatmentsPosition.reload()

        loopAPNSQrCodeURL.reload()
        bolusIncrementDetected.reload()
        showGMI.reload()
        showStdDev.reload()
        showTITR.reload()
    }

    // MARK: - Tab Position Helpers

    /// Get the position for a given tab item
    func position(for item: TabItem) -> TabPosition {
        switch item {
        case .home: homePosition.value
        case .alarms: alarmsPosition.value
        case .remote: remotePosition.value
        case .nightscout: nightscoutPosition.value
        case .snoozer: snoozerPosition.value
        case .stats: statisticsPosition.value
        case .treatments: treatmentsPosition.value
        }
    }

    /// Set the position for a given tab item
    func setPosition(_ position: TabPosition, for item: TabItem) {
        switch item {
        case .home: homePosition.value = position
        case .alarms: alarmsPosition.value = position
        case .remote: remotePosition.value = position
        case .nightscout: nightscoutPosition.value = position
        case .snoozer: snoozerPosition.value = position
        case .stats: statisticsPosition.value = position
        case .treatments: treatmentsPosition.value = position
        }
    }

    /// Get the tab item at a specific position (nil if no item at that position)
    func tabItem(at position: TabPosition) -> TabItem? {
        for item in TabItem.allCases {
            // Use normalized comparison to handle legacy values (.more, .disabled -> .menu)
            if self.position(for: item).normalized == position.normalized {
                return item
            }
        }
        return nil
    }

    /// Get all items in the Menu (position 5)
    func itemsInMenu() -> [TabItem] {
        TabItem.featureOrder.filter { position(for: $0).normalized == .menu }
    }

    /// Get items ordered by their position in the tab bar (positions 1-4)
    func orderedTabBarItems() -> [TabItem] {
        TabPosition.customizablePositions.compactMap { tabItem(at: $0) }
    }
}
