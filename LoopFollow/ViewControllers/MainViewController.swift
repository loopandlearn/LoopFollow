// LoopFollow
// MainViewController.swift

import AVFAudio
import Charts
import Combine
import CoreBluetooth
import EventKit
import ShareClient
import SwiftUI
import UIKit
import UserNotifications

func IsNightscoutEnabled() -> Bool {
    return !Storage.shared.url.value.isEmpty
}

private struct APNSCredentialSnapshot: Equatable {
    let remoteApnsKey: String
    let teamId: String?
    let remoteKeyId: String
    let lfApnsKey: String
    let lfKeyId: String
}

class MainViewController: UIViewController, ChartViewDelegate, UNUserNotificationCenterDelegate {
    /// Singleton reference set during viewDidLoad. Used by code that needs
    /// to reach MainViewController without walking the view hierarchy.
    private(set) weak static var shared: MainViewController?

    var isPresentedAsModal: Bool = false

    var BGChart: LineChartView!
    var BGChartFull: LineChartView!
    var statsDisplayModel = StatsDisplayModel()

    /// The hosting controller's view — hidden during loading / first-time setup.
    private var mainContentView: UIView!

    // Setup buttons for first-time configuration
    private var setupNightscoutButton: UIButton!
    private var setupDexcomButton: UIButton!

    let speechSynthesizer = AVSpeechSynthesizer()

    // Variables for BG Charts
    var firstGraphLoad: Bool = true
    var currentOverride = 1.0

    var currentSage: sageData?
    var currentCage: cageData?
    var currentIage: iageData?

    var backgroundTask = BackgroundTask()

    var graphNowTimer = Timer()

    var lastCalendarWriteAttemptTime: TimeInterval = 0

    // Info Table Setup
    var infoManager: InfoManager!
    var profileManager = ProfileManager.shared

    var bgData: [ShareGlucoseData] = []
    var basalProfile: [basalProfileStruct] = []
    var basalData: [basalGraphStruct] = []
    var basalScheduleData: [basalGraphStruct] = []
    var bolusData: [bolusGraphStruct] = []
    var smbData: [bolusGraphStruct] = []
    var carbData: [carbGraphStruct] = []

    // Stats-specific data storage (can hold up to 30 days)
    var statsBGData: [ShareGlucoseData] = []
    var statsBolusData: [bolusGraphStruct] = []
    var statsSMBData: [bolusGraphStruct] = []
    var statsCarbData: [carbGraphStruct] = []
    var statsBasalData: [basalGraphStruct] = []
    var overrideGraphData: [DataStructs.overrideStruct] = []
    var tempTargetGraphData: [DataStructs.tempTargetStruct] = []
    var predictionData: [ShareGlucoseData] = []
    var openAPSPredBGs: [String: [Double]]?
    var openAPSPredUpdatedTime: TimeInterval?
    var bgCheckData: [ShareGlucoseData] = []
    var suspendGraphData: [DataStructs.timestampOnlyStruct] = []
    var resumeGraphData: [DataStructs.timestampOnlyStruct] = []
    var sensorStartGraphData: [DataStructs.timestampOnlyStruct] = []
    var noteGraphData: [DataStructs.noteStruct] = []
    var chartData = LineChartData()
    var deviceBatteryData: [DataStructs.batteryStruct] = []
    var lastCalDate: Double = 0
    var latestLoopStatusString = ""
    var latestCOB: CarbMetric?
    var latestBasal = ""
    var latestPumpVolume: Double = 50.0
    var latestIOB: InsulinMetric?
    var lastOverrideStartTime: TimeInterval = 0
    var lastOverrideEndTime: TimeInterval = 0

    var topBG: Double = Storage.shared.minBGScale.value
    var topPredictionBG: Double = Storage.shared.minBGScale.value

    var lastOverrideAlarm: TimeInterval = 0

    var lastTempTargetAlarm: TimeInterval = 0
    var lastTempTargetStartTime: TimeInterval = 0
    var lastTempTargetEndTime: TimeInterval = 0

    // share
    var bgDataShare: [ShareGlucoseData] = []
    var dexShare: ShareClient?

    // calendar setup
    let store = EKEventStore()

    // Stores the timestamp of the last BG value that was spoken.
    var lastSpokenBGDate: TimeInterval = 0

    var autoScrollPauseUntil: Date?

    var IsNotLooping = false

    let contactImageUpdater = ContactImageUpdater()

    private var cancellables = Set<AnyCancellable>()

    // Loading state management
    private var loadingOverlay: UIView?
    private var isInitialLoad = true
    private var loadingStates: [String: Bool] = [
        "bg": false,
        "profile": false,
        "deviceStatus": false,
    ]
    private var loadingTimeoutTimer: Timer?

    // MARK: - Programmatic UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        BGChart = LineChartView()
        BGChart.backgroundColor = .systemBackground

        BGChartFull = LineChartView()
        BGChartFull.backgroundColor = .systemBackground

        infoManager = InfoManager()

        let mainView = MainHomeView(
            bgChart: BGChart,
            bgChartFull: BGChartFull,
            infoManager: infoManager,
            statsModel: statsDisplayModel,
            onRefresh: { [weak self] in self?.refresh() },
            onStatsTap: { [weak self] in self?.statsViewTapped() }
        )
        let hosting = UIHostingController(rootView: mainView)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: safeArea.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
        mainContentView = hosting.view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        MainViewController.shared = self

        setupUI()

        loadDebugData()

        // Migrations run in foreground only — see runMigrationsIfNeeded() for details.
        runMigrationsIfNeeded()

        // Synchronize info types to ensure arrays are the correct size
        synchronizeInfoTypes()

        let shareUserName = Storage.shared.shareUserName.value
        let sharePassword = Storage.shared.sharePassword.value
        let shareServer = Storage.shared.shareServer.value == "US" ?KnownShareServers.US.rawValue : KnownShareServers.NON_US.rawValue
        dexShare = ShareClient(username: shareUserName, password: sharePassword, shareServer: shareServer)

        // setup show/hide graphs (first-time setup check)
        updateGraphVisibility()

        BGChart.delegate = self
        BGChartFull.delegate = self

        // Apply initial appearance mode
        updateAppearance(Storage.shared.appearanceMode.value)

        // Trigger foreground and background functions
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        // didBecomeActive is used (not willEnterForeground) to ensure applicationState == .active
        // when runMigrationsIfNeeded() is called. This catches migrations deferred by a
        // background BGAppRefreshTask launch in Before-First-Unlock state.
        notificationCenter.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        #if !targetEnvironment(macCatalyst)
            notificationCenter.addObserver(self, selector: #selector(navigateOnLAForeground), name: .liveActivityDidForeground, object: nil)
        #endif

        // Setup the Graph
        if firstGraphLoad {
            createGraph()
            createSmallBGGraph()
        }

        // setup display for NS vs Dex
        showHideNSDetails()

        scheduleAllTasks()

        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name("refresh"), object: nil)

        /// When an alarm is triggered, go to the snoozer tab
        Observable.shared.currentAlarm.$value
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { _ in
                let orderedItems = Storage.shared.orderedTabBarItems()
                if let index = orderedItems.firstIndex(of: .snoozer) {
                    Observable.shared.selectedTabIndex.value = index
                }
            }
            .store(in: &cancellables)

        Storage.shared.colorBGText.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateBGTextAppearance()
            }
            .store(in: &cancellables)

        // Update appearance when setting changes
        Storage.shared.appearanceMode.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateAppearance(mode)
            }
            .store(in: &cancellables)

        Storage.shared.useIFCC.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)

        Storage.shared.screenlockSwitchState.$value
            .receive(on: DispatchQueue.main)
            .sink { newValue in
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
            .store(in: &cancellables)

        Storage.shared.showDisplayName.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateServerText()
            }
            .store(in: &cancellables)

        Storage.shared.speakBG.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateQuickActions()
            }
            .store(in: &cancellables)

        Storage.shared.url.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndShowImportButtonIfNeeded()
            }
            .store(in: &cancellables)

        Storage.shared.token.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndShowImportButtonIfNeeded()
            }
            .store(in: &cancellables)

        Storage.shared.shareUserName.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndShowImportButtonIfNeeded()
            }
            .store(in: &cancellables)

        Storage.shared.sharePassword.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndShowImportButtonIfNeeded()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            Storage.shared.remoteApnsKey.$value,
            Storage.shared.teamId.$value,
            Storage.shared.remoteKeyId.$value,
            Storage.shared.lfApnsKey.$value
        )
        .combineLatest(Storage.shared.lfKeyId.$value)
        .map { values, lfKeyId in
            APNSCredentialSnapshot(
                remoteApnsKey: values.0,
                teamId: values.1,
                remoteKeyId: values.2,
                lfApnsKey: values.3,
                lfKeyId: lfKeyId
            )
        }
        .removeDuplicates()
        .dropFirst()
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { _ in JWTManager.shared.invalidateCache() }
        .store(in: &cancellables)

        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let isTrioDevice = (Storage.shared.device.value == "Trio")
                let isLoopDevice = (Storage.shared.device.value == "Loop")

                let currentRemoteType = Storage.shared.remoteType.value

                // Check if current remote type is invalid for the device
                let shouldReset = (currentRemoteType == .loopAPNS && !isLoopDevice) ||
                    (currentRemoteType == .trc && !isTrioDevice)

                if shouldReset {
                    Storage.shared.remoteType.value = .none
                }
            }
            .store(in: &cancellables)

        Storage.shared.device.$value
            .receive(on: DispatchQueue.main)
            .map { device -> Bool? in
                device.isEmpty ? nil : (device == "Loop")
            }
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] isLoop in
                guard let isLoop = isLoop else { return }
                Storage.shared.predictionDisplayType.value = isLoop ? .lines : .cone
                self?.updateOpenAPSPredictionDisplay()
            }
            .store(in: &cancellables)

        updateQuickActions()

        speechSynthesizer.delegate = self

        // Check configuration and show appropriate UI
        if isDataSourceConfigured() {
            // Data source configured - show loading overlay
            setupLoadingState()
            showLoadingOverlay()
        } else {
            // No data source - hide all data UI and show setup buttons
            hideAllDataUI()
            isInitialLoad = false
        }

        checkAndShowImportButtonIfNeeded()
    }

    // MARK: - Loading Overlay

    private func isDataSourceConfigured() -> Bool {
        let isNightscoutConfigured = !Storage.shared.url.value.isEmpty
        let isDexcomConfigured = !Storage.shared.shareUserName.value.isEmpty && !Storage.shared.sharePassword.value.isEmpty
        return isNightscoutConfigured || isDexcomConfigured
    }

    private func setupLoadingState() {
        // If Nightscout is not enabled, mark profile and deviceStatus as loaded
        // since we only need BG data from Dexcom Share
        if !IsNightscoutEnabled() {
            loadingStates["profile"] = true
            loadingStates["deviceStatus"] = true
        }
    }

    private func showLoadingOverlay() {
        guard loadingOverlay == nil else { return }

        // Hide all data UI while loading
        hideAllDataUI()

        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.systemBackground
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        let loadingLabel = UILabel()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Loading..."
        loadingLabel.textAlignment = .center
        loadingLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        loadingLabel.textColor = UIColor.secondaryLabel

        overlay.addSubview(activityIndicator)
        overlay.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),

            loadingLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
        ])

        view.addSubview(overlay)
        loadingOverlay = overlay

        // Set a timeout to hide the loading overlay if data takes too long
        loadingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.isInitialLoad {
                LogManager.shared.log(category: .general, message: "Loading timeout reached, hiding overlay")
                self.isInitialLoad = false
                self.hideLoadingOverlay()
            }
        }
    }

    private func hideLoadingOverlay() {
        guard let overlay = loadingOverlay else { return }

        // Cancel the timeout timer
        loadingTimeoutTimer?.invalidate()
        loadingTimeoutTimer = nil

        // Show all data UI now that loading is complete
        showAllDataUI()

        UIView.animate(withDuration: 0.3, animations: {
            overlay.alpha = 0
        }, completion: { _ in
            overlay.removeFromSuperview()
            self.loadingOverlay = nil
        })
    }

    func markDataLoaded(_ key: String) {
        guard isInitialLoad else { return }

        loadingStates[key] = true

        // Check if all critical data is loaded
        let allLoaded = loadingStates.values.allSatisfy { $0 }
        if allLoaded {
            isInitialLoad = false
            DispatchQueue.main.async {
                self.hideLoadingOverlay()
            }
        }
    }

    @objc private func navigateOnLAForeground() {
        let orderedItems = Storage.shared.orderedTabBarItems()
        if Observable.shared.currentAlarm.value != nil,
           let snoozerIndex = orderedItems.firstIndex(of: .snoozer)
        {
            Observable.shared.selectedTabIndex.value = snoozerIndex
        } else {
            Observable.shared.selectedTabIndex.value = 0
        }
    }

    @objc private func statsViewTapped() {
        #if !targetEnvironment(macCatalyst)
            let orderedItems = Storage.shared.orderedTabBarItems()
            if let statsIndex = orderedItems.firstIndex(of: .stats) {
                Observable.shared.selectedTabIndex.value = statsIndex
                return
            }
        #endif

        let statsModalView = AggregatedStatsModalView(mainViewController: self)
        let hostingController = UIHostingController(rootView: statsModalView)
        hostingController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }

    // Update the Home Screen Quick Action for toggling the "Speak BG" feature based on the current speakBG setting.
    func updateQuickActions() {
        let iconName = Storage.shared.speakBG.value ? "pause.circle.fill" : "play.circle.fill"
        let iconTemplate = UIApplicationShortcutIcon(systemImageName: iconName)

        let shortcut = UIApplicationShortcutItem(type: Bundle.main.bundleIdentifier! + ".toggleSpeakBG",
                                                 localizedTitle: "Speak BG",
                                                 localizedSubtitle: nil,
                                                 icon: iconTemplate,
                                                 userInfo: nil)
        UIApplication.shared.shortcutItems = [shortcut]
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("refresh"), object: nil)
    }

    // Clean all timers and start new ones when refreshing
    @objc func refresh() {
        LogManager.shared.log(category: .general, message: "Refreshing")

        // Clear prediction for both Loop or OpenAPS

        // Check if Loop prediction data exists and clear it if necessary
        if !predictionData.isEmpty {
            predictionData.removeAll()
            updatePredictionGraph()
        }

        // Check if OpenAPS prediction data exists and clear it if necessary
        let openAPSDataIndices = [12, 13, 14, 15]
        for dataIndex in openAPSDataIndices {
            let mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
            let smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
            if !mainChart.entries.isEmpty || !smallChart.entries.isEmpty {
                updatePredictionGraphGeneric(
                    dataIndex: dataIndex,
                    predictionData: [],
                    chartLabel: "",
                    color: UIColor.systemGray
                )
            }
        }

        Observable.shared.minAgoText.value = "Refreshing"
        scheduleAllTasks()

        currentCage = nil
        currentSage = nil
        currentIage = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = Storage.shared.screenlockSwitchState.value

        if Observable.shared.chartSettingsChanged.value {
            updateBGGraphSettings()
            Observable.shared.chartSettingsChanged.value = false
        }
    }

    @objc func appMovedToBackground() {
        // Allow screen to turn off
        UIApplication.shared.isIdleTimerDisabled = false

        // We want to always come back to the home screen
        Observable.shared.selectedTabIndex.value = 0

        if Storage.shared.backgroundRefreshType.value == .silentTune {
            backgroundTask.startBackgroundTask()
            BackgroundRefreshManager.shared.scheduleRefresh()
        }

        if Storage.shared.backgroundRefreshType.value != .none {
            BackgroundAlertManager.shared.startBackgroundAlert()
        }
    }

    // Migrations must only run when UserDefaults is accessible (i.e. after first unlock).
    // When the app is launched in the background by BGAppRefreshTask immediately after a
    // reboot, the device may be in Before-First-Unlock (BFU) state: UserDefaults files are
    // still encrypted, so every read returns the default value (0 / ""). Running migrations
    // in that state would overwrite real settings with empty strings.
    //
    // Strategy: skip migrations if applicationState == .background; call this method again
    // from appCameToForeground() so they run on the first foreground after a BFU launch.
    func runMigrationsIfNeeded() {
        guard UIApplication.shared.applicationState != .background else { return }

        // Capture before migrations run: true for existing users, false for fresh installs.
        let isExistingUser = Storage.shared.migrationStep.exists

        // Step 1: Released in v3.0.0 (2025-07-07). Can be removed after 2026-07-07.
        if Storage.shared.migrationStep.value < 1 {
            Storage.shared.migrateStep1()
            Storage.shared.migrationStep.value = 1
        }

        // Step 2: Released in v3.1.0 (2025-07-21). Can be removed after 2026-07-21.
        if Storage.shared.migrationStep.value < 2 {
            Storage.shared.migrateStep2()
            Storage.shared.migrationStep.value = 2
        }

        // Step 3: Released in v4.5.0 (2026-02-01). Can be removed after 2027-02-01.
        if Storage.shared.migrationStep.value < 3 {
            Storage.shared.migrateStep3()
            Storage.shared.migrationStep.value = 3
        }

        // Step 4: Released in v5.0.0 (2026-03-20). Can be removed after 2027-03-20.
        if Storage.shared.migrationStep.value < 4 {
            // Existing users need to see the fat/protein order change banner.
            // New users never saw the old order, so mark it as already seen.
            Storage.shared.hasSeenFatProteinOrderChange.value = !isExistingUser
            Storage.shared.migrationStep.value = 4
        }

        // Step 5: Released in v5.0.0 (2026-03-20). Can be removed after 2027-03-20.
        if Storage.shared.migrationStep.value < 5 {
            Storage.shared.migrateStep5()
            Storage.shared.migrationStep.value = 5
        }

        if Storage.shared.migrationStep.value < 6 {
            Storage.shared.migrateStep6()
            Storage.shared.migrationStep.value = 6
        }

        if Storage.shared.migrationStep.value < 7 {
            Storage.shared.migrateStep7()
            Storage.shared.migrationStep.value = 7
        }
    }

    @objc func appDidBecomeActive() {
        // applicationState == .active is guaranteed here, so the BFU guard in
        // runMigrationsIfNeeded() will always pass. Catches the case where viewDidLoad
        // ran during a BGAppRefreshTask background launch and deferred migrations.
        runMigrationsIfNeeded()
    }

    @objc func appCameToForeground() {
        // If the app was cold-launched in Before-First-Unlock state (e.g. by BGAppRefreshTask
        // after a reboot), all StorageValues were cached from encrypted UserDefaults and hold
        // their defaults. Reload everything from disk now that the device is unlocked, firing
        // Combine observers only for values that actually changed.
        LogManager.shared.log(category: .general, message: "appCameToForeground: needsBFUReload=\(Storage.shared.needsBFUReload), url='\(LogRedactor.url(Storage.shared.url.value))'")
        if Storage.shared.needsBFUReload {
            Storage.shared.needsBFUReload = false
            LogManager.shared.log(category: .general, message: "BFU reload triggered — reloading all StorageValues")
            Storage.shared.reloadAll()
            LogManager.shared.log(category: .general, message: "BFU reload complete: url='\(LogRedactor.url(Storage.shared.url.value))'")
            // Show the loading overlay so the user sees feedback during the 2-5s
            // while tasks re-run with the now-correct credentials.
            loadingStates = ["bg": false, "profile": false, "deviceStatus": false]
            isInitialLoad = true
            setupLoadingState()
            showLoadingOverlay()
            // Tasks were scheduled during BFU viewDidLoad with url="" — they fired, found no
            // data source, and rescheduled themselves 60s out. Reset them now so they run
            // within their normal 2-5s initial delay using the now-correct credentials.
            scheduleAllTasks()
        }

        // reset screenlock state if needed
        UIApplication.shared.isIdleTimerDisabled = Storage.shared.screenlockSwitchState.value

        if Storage.shared.backgroundRefreshType.value == .silentTune {
            backgroundTask.stopBackgroundTask()
        }

        if Storage.shared.backgroundRefreshType.value != .none {
            BackgroundAlertManager.shared.stopBackgroundAlert()
        }

        TaskScheduler.shared.checkTasksNow()

        checkAndNotifyVersionStatus()
        checkAppExpirationStatus()
    }

    func checkAndNotifyVersionStatus() {
        let versionManager = AppVersionManager()
        versionManager.checkForNewVersion { latestVersion, isNewer, isBlacklisted in
            let now = Date()

            // Check if the current version is blacklisted, or if there is a newer version available
            if isBlacklisted {
                let lastBlacklistShown = Storage.shared.lastBlacklistNotificationShown.value ?? Date.distantPast
                if now.timeIntervalSince(lastBlacklistShown) > 86400 { // 24 hours
                    self.versionAlert(message: "The current version has a critical issue and should be updated as soon as possible.")
                    Storage.shared.lastBlacklistNotificationShown.value = now
                    Storage.shared.lastVersionUpdateNotificationShown.value = now
                }
            } else if isNewer {
                let lastVersionUpdateShown = Storage.shared.lastVersionUpdateNotificationShown.value ?? Date.distantPast
                if now.timeIntervalSince(lastVersionUpdateShown) > 1_209_600 { // 2 weeks
                    self.versionAlert(message: "A new version is available: \(latestVersion ?? "Unknown"). It is recommended to update.")
                    Storage.shared.lastVersionUpdateNotificationShown.value = now
                }
            }
        }
    }

    func versionAlert(title: String = "Update Available", message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }

    func checkAppExpirationStatus() {
        let now = Date()
        let expirationDate = BuildDetails.default.calculateExpirationDate()
        let weekBeforeExpiration = Calendar.current.date(byAdding: .day, value: -7, to: expirationDate)!

        if now >= weekBeforeExpiration {
            let lastExpirationShown = Storage.shared.lastExpirationNotificationShown.value ?? Date.distantPast
            if now.timeIntervalSince(lastExpirationShown) > 86400 { // 24 hours
                expirationAlert()
                Storage.shared.lastExpirationNotificationShown.value = now
            }
        }
    }

    func expirationAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "App Expiration Warning", message: "This app will expire in less than a week. Please rebuild to continue using it.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showHideNSDetails()
        #if !targetEnvironment(macCatalyst)
            LiveActivityManager.shared.startFromCurrentState()
        #endif
    }

    func stringFromTimeInterval(interval: TimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }

    func showHideNSDetails() {
        // Info table visibility is handled reactively by MainHomeView.
    }

    func updateBadge(val: Int) {
        if Storage.shared.appBadge.value {
            let latestBG = String(val)
            UIApplication.shared.applicationIconBadgeNumber = Int(Localizer.removePeriodAndCommaForBadge(Localizer.toDisplayUnits(latestBG))) ?? val
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func updateBGTextAppearance() {
        if bgData.count > 0 {
            let latestBG = bgData[bgData.count - 1].sgv
            if Storage.shared.colorBGText.value {
                if Double(latestBG) >= Storage.shared.highLine.value {
                    Observable.shared.bgTextColor.value = .yellow
                } else if Double(latestBG) <= Storage.shared.lowLine.value {
                    Observable.shared.bgTextColor.value = .red
                } else {
                    Observable.shared.bgTextColor.value = .green
                }
            } else {
                Observable.shared.bgTextColor.value = .primary
            }
        }
    }

    func updateAppearance(_ mode: AppearanceMode) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let style: UIUserInterfaceStyle
        switch mode {
        case .light:
            style = .light
        case .dark:
            style = .dark
        case .system:
            // Use .unspecified to follow system
            style = .unspecified
        }

        // Update this view controller
        overrideUserInterfaceStyle = style

        // Update the window (affects the entire app including modals)
        window.overrideUserInterfaceStyle = style
    }

    func bgDirectionGraphic(_ value: String) -> String {
        let // graphics:[String:String]=["Flat":"\u{2192}","DoubleUp":"\u{21C8}","SingleUp":"\u{2191}","FortyFiveUp":"\u{2197}\u{FE0E}","FortyFiveDown":"\u{2198}\u{FE0E}","SingleDown":"\u{2193}","DoubleDown":"\u{21CA}","None":"-","NOT COMPUTABLE":"-","RATE OUT OF RANGE":"-"]
            graphics: [String: String] = ["Flat": "→", "DoubleUp": "↑↑", "SingleUp": "↑", "FortyFiveUp": "↗", "FortyFiveDown": "↘︎", "SingleDown": "↓", "DoubleDown": "↓↓", "None": "-", "NONE": "-", "NOT COMPUTABLE": "-", "RATE OUT OF RANGE": "-", "": "-"]
        return graphics[value]!
    }

    func writeCalendar() {
        store.requestCalendarAccess { granted, error in
            if !granted {
                LogManager.shared.log(category: .calendar, message: "Failed to get calendar access: \(String(describing: error))")
                return
            }
            self.processCalendarUpdates()
        }
    }

    func processCalendarUpdates() {
        if Storage.shared.calendarIdentifier.value == "" { return }

        if bgData.count < 1 { return }

        // This lets us fire the method to write Min Ago entries only once a minute starting after 6 minutes but allows new readings through
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        let newestBGDate = bgData[bgData.count - 1].date

        if lastCalDate == newestBGDate {
            if (now - lastCalendarWriteAttemptTime) < 60 || (now - newestBGDate) < 360 {
                return
            }
        }

        // Create Event info
        var deltaBG = 0 // protect index out of bounds
        if bgData.count > 1 {
            deltaBG = bgData[bgData.count - 1].sgv - bgData[bgData.count - 2].sgv as Int
        }
        let deltaTime = (TimeInterval(Date().timeIntervalSince1970) - bgData[bgData.count - 1].date) / 60
        var deltaString = ""
        if deltaBG < 0 {
            deltaString = Localizer.toDisplayUnits(String(deltaBG))
        } else {
            deltaString = "+" + Localizer.toDisplayUnits(String(deltaBG))
        }
        let direction = bgDirectionGraphic(bgData[bgData.count - 1].direction ?? "")

        let eventStartDate = Date(timeIntervalSince1970: bgData[bgData.count - 1].date)
        var eventEndDate = eventStartDate.addingTimeInterval(60 * 10)
        var eventTitle = Storage.shared.watchLine1.value
        if Storage.shared.watchLine2.value.count > 1 {
            eventTitle += "\n" + Storage.shared.watchLine2.value
        }
        eventTitle = eventTitle.replacingOccurrences(of: "%BG%", with: Localizer.toDisplayUnits(String(bgData[bgData.count - 1].sgv)))
        eventTitle = eventTitle.replacingOccurrences(of: "%DIRECTION%", with: direction)
        eventTitle = eventTitle.replacingOccurrences(of: "%DELTA%", with: deltaString)
        if currentOverride != 1.0 {
            let val = Int(currentOverride * 100)
            // let overrideText = String(format:"%f1", self.currentOverride*100)
            let text = String(val) + "%"
            eventTitle = eventTitle.replacingOccurrences(of: "%OVERRIDE%", with: text)
        } else {
            eventTitle = eventTitle.replacingOccurrences(of: "%OVERRIDE%", with: "")
        }
        eventTitle = eventTitle.replacingOccurrences(of: "%LOOP%", with: latestLoopStatusString)
        var minAgo = ""
        if deltaTime > 9 {
            // write old BG reading and continue pushing out end date to show last entry
            minAgo = String(Int(deltaTime)) + " min"
            eventEndDate = eventStartDate.addingTimeInterval((60 * 10) + (deltaTime * 60))
        }
        var basal = "~"
        if latestBasal != "" {
            basal = latestBasal
        }
        eventTitle = eventTitle.replacingOccurrences(of: "%MINAGO%", with: minAgo)
        eventTitle = eventTitle.replacingOccurrences(of: "%IOB%", with: latestIOB?.formattedValue() ?? "0")
        eventTitle = eventTitle.replacingOccurrences(of: "%COB%", with: latestCOB?.formattedValue() ?? "0")
        eventTitle = eventTitle.replacingOccurrences(of: "%BASAL%", with: basal)

        // Delete Events from last 2 hours and 2 hours in future
        let deleteStartDate = Date().addingTimeInterval(-60 * 60 * 2)
        let deleteEndDate = Date().addingTimeInterval(60 * 60 * 2)
        // guard solves for some ios upgrades removing the calendar
        guard let deleteCalendar = store.calendar(withIdentifier: Storage.shared.calendarIdentifier.value) as? EKCalendar else { return }
        let predicate2 = store.predicateForEvents(withStart: deleteStartDate, end: deleteEndDate, calendars: [deleteCalendar])
        let eVDelete = store.events(matching: predicate2) as [EKEvent]?
        if eVDelete != nil {
            for i in eVDelete! {
                do {
                    try store.remove(i, span: EKSpan.thisEvent, commit: true)
                } catch {
                    LogManager.shared.log(category: .calendar, message: "Failed to remove calendar event: \(error.localizedDescription)")
                }
            }
        }

        // Write New Event
        let event = EKEvent(eventStore: store)
        event.title = eventTitle
        event.startDate = eventStartDate
        event.endDate = eventEndDate
        event.calendar = store.calendar(withIdentifier: Storage.shared.calendarIdentifier.value)
        do {
            try store.save(event, span: .thisEvent, commit: true)
            lastCalendarWriteAttemptTime = now

            lastCalDate = bgData[bgData.count - 1].date
        } catch {
            let msg = "Error storing to calendar: \(error.localizedDescription) (\(error))"
            LogManager.shared.log(category: .calendar, message: msg)
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive _: UNNotificationResponse, withCompletionHandler _: @escaping () -> Void) {}

    // User has scrolled the chart
    func chartTranslated(_: ChartViewBase, dX _: CGFloat, dY _: CGFloat) {
        let isViewingLatestData = abs(BGChart.highestVisibleX - BGChart.chartXMax) < 0.001
        if isViewingLatestData {
            autoScrollPauseUntil = nil // User is back at the latest data, allow auto-scrolling
        } else {
            autoScrollPauseUntil = Date().addingTimeInterval(5 * 60) // User is viewing historical data, pause auto-scrolling
        }
    }

    func calculateMaxBgGraphValue() -> Float {
        return max(Float(topBG), Float(topPredictionBG))
    }

    func loadDebugData() {
        struct DebugData: Codable {
            let debug: Bool?
            let url: String?
            let token: String?
        }

        let fileManager = FileManager.default
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("debugData.json")

        if fileManager.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let debugData = try decoder.decode(DebugData.self, from: data)
                LogManager.shared.log(category: .alarm, message: "Loaded DebugData from \(url.path)", isDebug: true)

                if let debug = debugData.debug {
                    Observable.shared.debug.value = debug
                }

                if let url = debugData.url {
                    Storage.shared.url.value = url
                }

                if let token = debugData.token {
                    Storage.shared.token.value = token
                }
            } catch {
                LogManager.shared.log(category: .alarm, message: "Failed to load DebugData: \(error)", isDebug: true)
            }
        }
    }

    private func synchronizeInfoTypes() {
        var sortArray = Storage.shared.infoSort.value
        var visibleArray = Storage.shared.infoVisible.value

        // Current valid indices based on InfoType
        let currentValidIndices = InfoType.allCases.map { $0.rawValue }

        // Add missing indices to sortArray
        for index in currentValidIndices {
            if !sortArray.contains(index) {
                sortArray.append(index)
            }
        }

        // Remove deprecated indices
        sortArray = sortArray.filter { currentValidIndices.contains($0) }

        // Ensure visibleArray is updated with new entries
        if visibleArray.count < currentValidIndices.count {
            for i in visibleArray.count ..< currentValidIndices.count {
                visibleArray.append(InfoType(rawValue: i)?.defaultVisible ?? false)
            }
        }

        // Trim excess elements if there are more than needed
        if visibleArray.count > currentValidIndices.count {
            visibleArray = Array(visibleArray.prefix(currentValidIndices.count))
        }

        Storage.shared.infoSort.value = sortArray
        Storage.shared.infoVisible.value = visibleArray
    }

    // MARK: - First Time Setup

    private func checkAndShowImportButtonIfNeeded() {
        // Check if this is first-time setup (no data source configured)
        let isFirstTimeSetup = !isDataSourceConfigured()

        if isFirstTimeSetup {
            setupFirstTimeButtons()
            hideAllDataUI()
            // Hide loading overlay if it's showing and mark as not loading
            if loadingOverlay != nil {
                isInitialLoad = false
                hideLoadingOverlay()
            }
        } else {
            hideFirstTimeButtons()
            // Only show data UI if we're not in initial loading state
            if !isInitialLoad || loadingOverlay == nil {
                showAllDataUI()
            }
        }
    }

    private func setupFirstTimeButtons() {
        // Create Setup Nightscout button
        if setupNightscoutButton == nil {
            setupNightscoutButton = UIButton(type: .system)
            setupNightscoutButton.setTitle("Setup Nightscout", for: .normal)
            setupNightscoutButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            setupNightscoutButton.backgroundColor = UIColor.systemBlue
            setupNightscoutButton.setTitleColor(.white, for: .normal)
            setupNightscoutButton.layer.cornerRadius = 12
            setupNightscoutButton.layer.shadowColor = UIColor.black.cgColor
            setupNightscoutButton.layer.shadowOffset = CGSize(width: 0, height: 2)
            setupNightscoutButton.layer.shadowOpacity = 0.3
            setupNightscoutButton.layer.shadowRadius = 4
            setupNightscoutButton.addTarget(self, action: #selector(setupNightscoutTapped), for: .touchUpInside)

            view.addSubview(setupNightscoutButton)
            setupNightscoutButton.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                setupNightscoutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                setupNightscoutButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
                setupNightscoutButton.widthAnchor.constraint(equalToConstant: 200),
                setupNightscoutButton.heightAnchor.constraint(equalToConstant: 50),
            ])
        }

        // Create Setup Dexcom Share button
        if setupDexcomButton == nil {
            setupDexcomButton = UIButton(type: .system)
            setupDexcomButton.setTitle("Setup Dexcom Share", for: .normal)
            setupDexcomButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            setupDexcomButton.backgroundColor = UIColor.systemGreen
            setupDexcomButton.setTitleColor(.white, for: .normal)
            setupDexcomButton.layer.cornerRadius = 12
            setupDexcomButton.layer.shadowColor = UIColor.black.cgColor
            setupDexcomButton.layer.shadowOffset = CGSize(width: 0, height: 2)
            setupDexcomButton.layer.shadowOpacity = 0.3
            setupDexcomButton.layer.shadowRadius = 4
            setupDexcomButton.addTarget(self, action: #selector(setupDexcomTapped), for: .touchUpInside)

            view.addSubview(setupDexcomButton)
            setupDexcomButton.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                setupDexcomButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                setupDexcomButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),
                setupDexcomButton.widthAnchor.constraint(equalToConstant: 200),
                setupDexcomButton.heightAnchor.constraint(equalToConstant: 50),
            ])
        }

        setupNightscoutButton.isHidden = false
        setupDexcomButton.isHidden = false
    }

    private func hideFirstTimeButtons() {
        setupNightscoutButton?.isHidden = true
        setupDexcomButton?.isHidden = true
    }

    @objc private func setupNightscoutTapped() {
        let nightscoutSettingsView = NightscoutSettingsView(viewModel: .init())
        let hostingController = UIHostingController(rootView: nightscoutSettingsView)
        let navController = UINavigationController(rootViewController: hostingController)

        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        hostingController.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        hostingController.navigationItem.rightBarButtonItem = makeCloseBarButtonItem()

        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true)
    }

    @objc private func setupDexcomTapped() {
        let dexcomSettingsView = DexcomSettingsView(viewModel: .init())
        let hostingController = UIHostingController(rootView: dexcomSettingsView)
        let navController = UINavigationController(rootViewController: hostingController)

        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        hostingController.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        hostingController.navigationItem.rightBarButtonItem = makeCloseBarButtonItem()

        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true)
    }

    private func makeCloseBarButtonItem() -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(dismissModal))
        button.tintColor = .systemBlue
        return button
    }

    private func hideAllDataUI() {
        mainContentView?.isHidden = true
    }

    private func showAllDataUI() {
        mainContentView?.isHidden = false
    }

    private func updateGraphVisibility() {
        // Graph and component visibility is handled reactively by MainHomeView.
        // This method now only manages the overall content visibility for first-time setup.
        if !isDataSourceConfigured() {
            mainContentView?.isHidden = true
        }
    }

    @objc private func importSettingsButtonTapped() {
        presentImportSettingsView()
    }

    private func presentImportSettingsView() {
        let importExportView = ImportExportSettingsView()
        let hostingController = UIHostingController(rootView: importExportView)
        hostingController.modalPresentationStyle = .pageSheet

        present(hostingController, animated: true)
    }

    @objc private func dismissModal() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            // Check if user just configured a data source
            if self.isDataSourceConfigured(), self.loadingOverlay == nil {
                // Reset loading states for fresh load
                self.loadingStates = [
                    "bg": false,
                    "profile": false,
                    "deviceStatus": false,
                ]
                self.isInitialLoad = true

                // Show loading overlay and trigger refresh
                self.setupLoadingState()
                self.showLoadingOverlay()
                self.refresh()
            }
        }
    }
}

extension MainViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        let appState = UIApplication.shared.applicationState
        let isSilentTuneMode = Storage.shared.backgroundRefreshType.value == .silentTune

        if isSilentTuneMode, appState == .background {
            LogManager.shared.log(category: .general, message: "Silent tune active in background; not deactivating session.", isDebug: true)
        } else {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                LogManager.shared.log(category: .general, message: "Audio session deactivated after speech.", isDebug: true)
            } catch {
                LogManager.shared.log(category: .alarm, message: "Failed to deactivate audio session: \(error)")
            }
        }
    }
}
