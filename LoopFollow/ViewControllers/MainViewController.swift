// LoopFollow
// MainViewController.swift
// Created by Jon Fawcett on 2020-06-17.

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
    return !ObservableUserDefaults.shared.url.value.isEmpty
}

class MainViewController: UIViewController, UITableViewDataSource, ChartViewDelegate, UNUserNotificationCenterDelegate, UIScrollViewDelegate {
    @IBOutlet var BGText: UILabel!
    @IBOutlet var DeltaText: UILabel!
    @IBOutlet var DirectionText: UILabel!
    @IBOutlet var BGChart: LineChartView!
    @IBOutlet var BGChartFull: LineChartView!
    @IBOutlet var MinAgoText: UILabel!
    @IBOutlet var infoTable: UITableView!
    @IBOutlet var Console: UITableViewCell!
    @IBOutlet var DragBar: UIImageView!
    @IBOutlet var PredictionLabel: UILabel!
    @IBOutlet var LoopStatusLabel: UILabel!
    @IBOutlet var statsPieChart: PieChartView!
    @IBOutlet var statsLowPercent: UILabel!
    @IBOutlet var statsInRangePercent: UILabel!
    @IBOutlet var statsHighPercent: UILabel!
    @IBOutlet var statsAvgBG: UILabel!
    @IBOutlet var statsEstA1C: UILabel!
    @IBOutlet var statsStdDev: UILabel!
    @IBOutlet var serverText: UILabel!
    @IBOutlet var statsView: UIView!
    @IBOutlet var smallGraphHeightConstraint: NSLayoutConstraint!
    var refreshScrollView: UIScrollView!
    var refreshControl: UIRefreshControl!

    let speechSynthesizer = AVSpeechSynthesizer()

    var appStateController: AppStateController?

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
    var overrideGraphData: [DataStructs.overrideStruct] = []
    var tempTargetGraphData: [DataStructs.tempTargetStruct] = []
    var predictionData: [ShareGlucoseData] = []
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

    var topBG: Float = UserDefaultsRepository.minBGScale.value
    var topPredictionBG: Float = UserDefaultsRepository.minBGScale.value

    var lastOverrideAlarm: TimeInterval = 0

    var lastTempTargetAlarm: TimeInterval = 0
    var lastTempTargetStartTime: TimeInterval = 0
    var lastTempTargetEndTime: TimeInterval = 0

    // share
    var bgDataShare: [ShareGlucoseData] = []
    var dexShare: ShareClient?

    // calendar setup
    let store = EKEventStore()

    // Stores the time of the last speech announcement to prevent repeated announcements.
    var lastSpeechTime: Date?

    var autoScrollPauseUntil: Date? = nil

    var IsNotLooping = false

    let contactImageUpdater = ContactImageUpdater()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        loadDebugData()

        if ObservableUserDefaults.shared.device.value != "Trio" && Storage.shared.remoteType.value == .trc {
            Storage.shared.remoteType.value = .none
        }

        // Migration of UserDefaultsRepository -> Storage handling
        if !UserDefaultsRepository.backgroundRefresh.value {
            Storage.shared.backgroundRefreshType.value = .none
            UserDefaultsRepository.backgroundRefresh.value = true
        }

        // Remove this in a year later than the release of the new Alarms [BEGIN]
        let legacyColorBGText = UserDefaultsValue<Bool>(key: "colorBGText", default: true)
        if legacyColorBGText.exists {
            Storage.shared.colorBGText.value = legacyColorBGText.value
            legacyColorBGText.setNil(key: "colorBGText")
        }

        let legacyAppBadge = UserDefaultsValue<Bool>(key: "appBadge", default: true)
        if legacyAppBadge.exists {
            Storage.shared.appBadge.value = legacyAppBadge.value
            legacyAppBadge.setNil(key: "appBadge")
        }

        let legacyForceDarkMode = UserDefaultsValue<Bool>(key: "forceDarkMode", default: true)
        if legacyForceDarkMode.exists {
            Storage.shared.forceDarkMode.value = legacyForceDarkMode.value
            legacyForceDarkMode.setNil(key: "forceDarkMode")
        }

        let legacyShowStats = UserDefaultsValue<Bool>(key: "showStats", default: true)
        if legacyShowStats.exists {
            Storage.shared.showStats.value = legacyShowStats.value
            legacyShowStats.setNil(key: "showStats")
        }

        let legacyUseIFCC = UserDefaultsValue<Bool>(key: "useIFCC", default: false)
        if legacyUseIFCC.exists {
            Storage.shared.useIFCC.value = legacyUseIFCC.value
            legacyUseIFCC.setNil(key: "useIFCC")
        }

        let legacyShowSmallGraph = UserDefaultsValue<Bool>(key: "showSmallGraph", default: true)
        if legacyShowSmallGraph.exists {
            Storage.shared.showSmallGraph.value = legacyShowSmallGraph.value
            legacyShowSmallGraph.setNil(key: "showSmallGraph")
        }

        let legacyScreenlockSwitchState = UserDefaultsValue<Bool>(key: "screenlockSwitchState", default: true)
        if legacyScreenlockSwitchState.exists {
            Storage.shared.screenlockSwitchState.value = legacyScreenlockSwitchState.value
            legacyScreenlockSwitchState.setNil(key: "screenlockSwitchState")
        }

        let legacyShowDisplayName = UserDefaultsValue<Bool>(key: "showDisplayName", default: false)
        if legacyShowDisplayName.exists {
            Storage.shared.showDisplayName.value = legacyShowDisplayName.value
            legacyShowDisplayName.setNil(key: "showDisplayName")
        }

        let legacySpeakBG = UserDefaultsValue<Bool>(key: "speakBG", default: false)
        if legacySpeakBG.exists {
            Storage.shared.speakBG.value = legacySpeakBG.value
            legacySpeakBG.setNil(key: "speakBG")
        }

        let legacySpeakBGAlways = UserDefaultsValue<Bool>(key: "speakBGAlways", default: true)
        if legacySpeakBGAlways.exists {
            Storage.shared.speakBGAlways.value = legacySpeakBGAlways.value
            legacySpeakBGAlways.setNil(key: "speakBGAlways")
        }

        let legacySpeakLowBG = UserDefaultsValue<Bool>(key: "speakLowBG", default: false)
        if legacySpeakLowBG.exists {
            Storage.shared.speakLowBG.value = legacySpeakLowBG.value
            legacySpeakLowBG.setNil(key: "speakLowBG")
        }

        let legacySpeakProactiveLowBG = UserDefaultsValue<Bool>(key: "speakProactiveLowBG", default: false)
        if legacySpeakProactiveLowBG.exists {
            Storage.shared.speakProactiveLowBG.value = legacySpeakProactiveLowBG.value
            legacySpeakProactiveLowBG.setNil(key: "speakProactiveLowBG")
        }

        let legacySpeakFastDropDelta = UserDefaultsValue<Float>(key: "speakFastDropDelta", default: 10.0)
        if legacySpeakFastDropDelta.exists {
            Storage.shared.speakFastDropDelta.value = Double(legacySpeakFastDropDelta.value)
            legacySpeakFastDropDelta.setNil(key: "speakFastDropDelta")
        }

        let legacySpeakLowBGLimit = UserDefaultsValue<Float>(key: "speakLowBGLimit", default: 72.0)
        if legacySpeakLowBGLimit.exists {
            Storage.shared.speakLowBGLimit.value = Double(legacySpeakLowBGLimit.value)
            legacySpeakLowBGLimit.setNil(key: "speakLowBGLimit")
        }

        let legacySpeakHighBGLimit = UserDefaultsValue<Float>(key: "speakHighBGLimit", default: 180.0)
        if legacySpeakHighBGLimit.exists {
            Storage.shared.speakHighBGLimit.value = Double(legacySpeakHighBGLimit.value)
            legacySpeakHighBGLimit.setNil(key: "speakHighBGLimit")
        }

        let legacySpeakHighBG = UserDefaultsValue<Bool>(key: "speakHighBG", default: false)
        if legacySpeakHighBG.exists {
            Storage.shared.speakHighBG.value = legacySpeakHighBG.value
            legacySpeakHighBG.setNil(key: "speakHighBG")
        }

        let legacySpeakLanguage = UserDefaultsValue<String>(key: "speakLanguage", default: "en")
        if legacySpeakLanguage.exists {
            Storage.shared.speakLanguage.value = legacySpeakLanguage.value
            legacySpeakLanguage.setNil(key: "speakLanguage")
        }

        // Remove this in a year later than the release of the new Alarms [END]

        // Ensure alertNotLooping has a minimum value of 16.
        if UserDefaultsRepository.alertNotLooping.value < 16 {
            UserDefaultsRepository.alertNotLooping.value = 16
        }

        // Synchronize info types to ensure arrays are the correct size
        UserDefaultsRepository.synchronizeInfoTypes()

        infoTable.rowHeight = 21
        infoTable.dataSource = self
        infoTable.tableFooterView = UIView(frame: .zero)
        infoTable.bounces = false
        infoTable.addBorder(toSide: .Left, withColor: UIColor.darkGray.cgColor, andThickness: 2)

        infoManager = InfoManager(tableView: infoTable)

        smallGraphHeightConstraint.constant = CGFloat(UserDefaultsRepository.smallGraphHeight.value)
        view.layoutIfNeeded()

        let shareUserName = UserDefaultsRepository.shareUserName.value
        let sharePassword = UserDefaultsRepository.sharePassword.value
        let shareServer = UserDefaultsRepository.shareServer.value == "US" ?KnownShareServers.US.rawValue : KnownShareServers.NON_US.rawValue
        dexShare = ShareClient(username: shareUserName, password: sharePassword, shareServer: shareServer)

        // setup show/hide small graph and stats
        BGChartFull.isHidden = !Storage.shared.showSmallGraph.value
        statsView.isHidden = !Storage.shared.showStats.value

        BGChart.delegate = self
        BGChartFull.delegate = self

        if Storage.shared.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
            tabBarController?.overrideUserInterfaceStyle = .dark
        }

        // Trigger foreground and background functions
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        // Setup the Graph
        if firstGraphLoad {
            createGraph()
            createSmallBGGraph()
        }

        // setup display for NS vs Dex
        showHideNSDetails()

        scheduleAllTasks()

        // Set up refreshScrollView for BGText
        refreshScrollView = UIScrollView()
        refreshScrollView.translatesAutoresizingMaskIntoConstraints = false
        refreshScrollView.alwaysBounceVertical = true
        view.addSubview(refreshScrollView)

        NSLayoutConstraint.activate([
            refreshScrollView.leadingAnchor.constraint(equalTo: BGText.leadingAnchor),
            refreshScrollView.trailingAnchor.constraint(equalTo: BGText.trailingAnchor),
            refreshScrollView.topAnchor.constraint(equalTo: BGText.topAnchor),
            refreshScrollView.bottomAnchor.constraint(equalTo: BGText.bottomAnchor),
        ])

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        refreshScrollView.addSubview(refreshControl)

        // Add this line to prevent scrolling in other directions
        refreshScrollView.alwaysBounceVertical = true

        refreshScrollView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name("refresh"), object: nil)

        Observable.shared.bgText.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.BGText.text = newValue
            }
            .store(in: &cancellables)

        Observable.shared.directionText.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.DirectionText.text = newValue
            }
            .store(in: &cancellables)

        Observable.shared.deltaText.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.DeltaText.text = newValue
            }
            .store(in: &cancellables)

        /// When an alarm is triggered, go to the snoozer tab
        Observable.shared.currentAlarm.$value
            .receive(on: DispatchQueue.main)
            .compactMap { $0 } /// Ignore nil
            .sink { [weak self] _ in
                self?.tabBarController?.selectedIndex = 2
            }
            .store(in: &cancellables)

        Storage.shared.colorBGText.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setBGTextColor()
            }
            .store(in: &cancellables)

        Storage.shared.showStats.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statsView.isHidden = !Storage.shared.showStats.value
            }
            .store(in: &cancellables)

        Storage.shared.useIFCC.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStats()
            }
            .store(in: &cancellables)

        Storage.shared.showSmallGraph.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.BGChartFull.isHidden = !Storage.shared.showSmallGraph.value
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

        updateQuickActions()
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

        MinAgoText.text = "Refreshing"
        Observable.shared.minAgoText.value = "Refreshing"
        scheduleAllTasks()

        currentCage = nil
        currentSage = nil
        currentIage = nil
        lastSpeechTime = nil
        refreshControl.endRefreshing()
    }

    // Scroll down BGText when refreshing
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == refreshScrollView {
            let yOffset = scrollView.contentOffset.y
            if yOffset < 0 {
                BGText.transform = CGAffineTransform(translationX: 0, y: -yOffset)
            } else {
                BGText.transform = CGAffineTransform.identity
            }
        }
    }

    override func viewWillAppear(_: Bool) {
        // set screen lock
        UIApplication.shared.isIdleTimerDisabled = Storage.shared.screenlockSwitchState.value

        // check the app state
        if let appState = appStateController {
            if appState.chartSettingsChanged {
                // can look at settings flags to be more fine tuned
                updateBGGraphSettings()

                if ChartSettingsChangeEnum.smallGraphHeight.rawValue != 0 {
                    smallGraphHeightConstraint.constant = CGFloat(UserDefaultsRepository.smallGraphHeight.value)
                    view.layoutIfNeeded()
                }

                // reset the app state
                appState.chartSettingsChanged = false
                appState.chartSettingsChanges = 0
            }
            if appState.generalSettingsChanged {
                // reset the app state
                appState.generalSettingsChanged = false
                appState.generalSettingsChanges = 0
            }
            if appState.infoDataSettingsChanged {
                infoTable.reloadData()

                // reset
                appState.infoDataSettingsChanged = false
            }

            // add more processing of the app state
        }
    }

    // Info Table Functions
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let infoManager = infoManager else {
            return 0
        }
        return infoManager.numberOfRows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)

        if let values = infoManager.dataForIndexPath(indexPath) {
            cell.textLabel?.text = values.name
            cell.detailTextLabel?.text = values.value
        } else {
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
        }

        return cell
    }

    @objc func appMovedToBackground() {
        // Allow screen to turn off
        UIApplication.shared.isIdleTimerDisabled = false

        // We want to always come back to the home screen
        tabBarController?.selectedIndex = 0

        if Storage.shared.backgroundRefreshType.value == .silentTune {
            backgroundTask.startBackgroundTask()
        }

        if Storage.shared.backgroundRefreshType.value != .none {
            BackgroundAlertManager.shared.startBackgroundAlert()
        }
    }

    @objc func appCameToForeground() {
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
                let lastBlacklistShown = UserDefaultsRepository.lastBlacklistNotificationShown.value ?? Date.distantPast
                if now.timeIntervalSince(lastBlacklistShown) > 86400 { // 24 hours
                    self.versionAlert(message: "The current version has a critical issue and should be updated as soon as possible.")
                    UserDefaultsRepository.lastBlacklistNotificationShown.value = now
                    UserDefaultsRepository.lastVersionUpdateNotificationShown.value = now
                }
            } else if isNewer {
                let lastVersionUpdateShown = UserDefaultsRepository.lastVersionUpdateNotificationShown.value ?? Date.distantPast
                if now.timeIntervalSince(lastVersionUpdateShown) > 1_209_600 { // 2 weeks
                    self.versionAlert(message: "A new version is available: \(latestVersion ?? "Unknown"). It is recommended to update.")
                    UserDefaultsRepository.lastVersionUpdateNotificationShown.value = now
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
            let lastExpirationShown = UserDefaultsRepository.lastExpirationNotificationShown.value ?? Date.distantPast
            if now.timeIntervalSince(lastExpirationShown) > 86400 { // 24 hours
                expirationAlert()
                UserDefaultsRepository.lastExpirationNotificationShown.value = now
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

    @objc override func viewDidAppear(_: Bool) {
        showHideNSDetails()
    }

    func stringFromTimeInterval(interval: TimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }

    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if !IsNightscoutEnabled() {
            isHidden = true
            isEnabled = false
        }

        LoopStatusLabel.isHidden = isHidden
        if IsNotLooping {
            PredictionLabel.isHidden = true
        } else {
            PredictionLabel.isHidden = isHidden
        }
        infoTable.isHidden = isHidden

        if UserDefaultsRepository.hideInfoTable.value {
            infoTable.isHidden = true
        }

        if IsNightscoutEnabled() {
            isEnabled = true
        }

        guard let nightscoutTab = tabBarController?.tabBar.items![3] else { return }
        nightscoutTab.isEnabled = isEnabled
    }

    func updateBadge(val: Int) {
        if Storage.shared.appBadge.value {
            let latestBG = String(val)
            UIApplication.shared.applicationIconBadgeNumber = Int(Localizer.removePeriodAndCommaForBadge(Localizer.toDisplayUnits(latestBG))) ?? val
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func setBGTextColor() {
        if bgData.count > 0 {
            let latestBG = bgData[bgData.count - 1].sgv
            var color = NSUIColor.label
            if Storage.shared.colorBGText.value {
                if Float(latestBG) >= UserDefaultsRepository.highLine.value {
                    color = NSUIColor.systemYellow
                    Observable.shared.bgTextColor.value = .yellow
                } else if Float(latestBG) <= UserDefaultsRepository.lowLine.value {
                    color = NSUIColor.systemRed
                    Observable.shared.bgTextColor.value = .red
                } else {
                    color = NSUIColor.systemGreen
                    Observable.shared.bgTextColor.value = .green
                }
            } else {
                Observable.shared.bgTextColor.value = .primary
            }

            BGText.textColor = color
        }
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
        if UserDefaultsRepository.calendarIdentifier.value == "" { return }

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

        var eventStartDate = Date(timeIntervalSince1970: bgData[bgData.count - 1].date)
        var eventEndDate = eventStartDate.addingTimeInterval(60 * 10)
        var eventTitle = UserDefaultsRepository.watchLine1.value
        if UserDefaultsRepository.watchLine2.value.count > 1 {
            eventTitle += "\n" + UserDefaultsRepository.watchLine2.value
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
        var deleteStartDate = Date().addingTimeInterval(-60 * 60 * 2)
        var deleteEndDate = Date().addingTimeInterval(60 * 60 * 2)
        // guard solves for some ios upgrades removing the calendar
        guard let deleteCalendar = store.calendar(withIdentifier: UserDefaultsRepository.calendarIdentifier.value) as? EKCalendar else { return }
        var predicate2 = store.predicateForEvents(withStart: deleteStartDate, end: deleteEndDate, calendars: [deleteCalendar])
        var eVDelete = store.events(matching: predicate2) as [EKEvent]?
        if eVDelete != nil {
            for i in eVDelete! {
                do {
                    try store.remove(i, span: EKSpan.thisEvent, commit: true)
                } catch {
                    print(error)
                }
            }
        }

        // Write New Event
        var event = EKEvent(eventStore: store)
        event.title = eventTitle
        event.startDate = eventStartDate
        event.endDate = eventEndDate
        event.calendar = store.calendar(withIdentifier: UserDefaultsRepository.calendarIdentifier.value)
        do {
            try store.save(event, span: .thisEvent, commit: true)
            lastCalendarWriteAttemptTime = now

            lastCalDate = bgData[bgData.count - 1].date
            // UserDefaultsRepository.savedEventID.value = event.eventIdentifier //save event id to access this particular event later
        } catch {
            LogManager.shared.log(category: .calendar, message: "Error storing to the calendar")
        }
    }

    func sendGeneralNotification(_: Any, title: String, subtitle: String, body: String, timer: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.categoryIdentifier = "noAction"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timer, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
        return max(topBG, topPredictionBG)
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
                    ObservableUserDefaults.shared.url.value = url
                }

                if let token = debugData.token {
                    UserDefaultsRepository.token.value = token
                }
            } catch {
                LogManager.shared.log(category: .alarm, message: "Failed to load DebugData: \(error)", isDebug: true)
            }
        }
    }
}
