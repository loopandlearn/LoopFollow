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

private enum SecondTab {
    case remote
    case alarms
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

    override func viewDidLoad() {
        super.viewDidLoad()

        loadDebugData()

        if Storage.shared.migrationStep.value < 1 {
            Storage.shared.migrateStep1()
            Storage.shared.migrationStep.value = 1
        }

        if Storage.shared.migrationStep.value < 2 {
            Storage.shared.migrateStep2()
            Storage.shared.migrationStep.value = 2
        }

        // Synchronize info types to ensure arrays are the correct size
        synchronizeInfoTypes()

        infoTable.rowHeight = 21
        infoTable.dataSource = self
        infoTable.tableFooterView = UIView(frame: .zero)
        infoTable.bounces = false
        infoTable.addBorder(toSide: .Left, withColor: UIColor.darkGray.cgColor, andThickness: 2)

        infoManager = InfoManager(tableView: infoTable)

        smallGraphHeightConstraint.constant = CGFloat(Storage.shared.smallGraphHeight.value)
        view.layoutIfNeeded()

        let shareUserName = Storage.shared.shareUserName.value
        let sharePassword = Storage.shared.sharePassword.value
        let shareServer = Storage.shared.shareServer.value == "US" ?KnownShareServers.US.rawValue : KnownShareServers.NON_US.rawValue
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
            .compactMap { $0 }
            .sink { [weak self] _ in
                if let snoozerIndex = self?.getSnoozerTabIndex() {
                    self?.tabBarController?.selectedIndex = snoozerIndex
                }
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

        Storage.shared.alarmsPosition.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupTabBar()
            }
            .store(in: &cancellables)

        Storage.shared.remotePosition.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupTabBar()
            }
            .store(in: &cancellables)

        Storage.shared.nightscoutPosition.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupTabBar()
            }
            .store(in: &cancellables)

        Storage.shared.url.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNightscoutTabState()
            }
            .store(in: &cancellables)

        Storage.shared.apnsKey.$value
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { _ in
                JWTManager.shared.invalidateCache()
            }
            .store(in: &cancellables)

        Storage.shared.teamId.$value
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { _ in
                JWTManager.shared.invalidateCache()
            }
            .store(in: &cancellables)

        Storage.shared.keyId.$value
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { _ in
                JWTManager.shared.invalidateCache()
            }
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
                    (currentRemoteType == .trc && !isTrioDevice) ||
                    (currentRemoteType == .nightscout && !isTrioDevice)

                if shouldReset {
                    Storage.shared.remoteType.value = .none
                }
            }
            .store(in: &cancellables)

        updateQuickActions()
        setupTabBar()

        speechSynthesizer.delegate = self
    }

    private func setupTabBar() {
        guard let tabBarController = tabBarController else { return }

        // Store current selection before making changes
        let currentSelectedIndex = tabBarController.selectedIndex

        // Check if we need to handle More tab disappearing
        let wasInMoreTab = currentSelectedIndex == 4 &&
            tabBarController.viewControllers?.last is MoreMenuViewController
        let willHaveMoreTab = hasItemsInMore()

        // If currently in More tab and it's going away, we need to handle this carefully
        if wasInMoreTab, !willHaveMoreTab {
            // First, dismiss any modals that might be open
            if let presented = tabBarController.presentedViewController {
                presented.dismiss(animated: false) { [weak self] in
                    // After dismissal, rebuild tabs with home selected
                    self?.rebuildTabs(tabBarController: tabBarController,
                                      willHaveMoreTab: willHaveMoreTab,
                                      selectedIndex: 0)
                }
                return
            }
        }

        // For all other cases, rebuild tabs normally
        rebuildTabs(tabBarController: tabBarController,
                    willHaveMoreTab: willHaveMoreTab,
                    selectedIndex: wasInMoreTab && !willHaveMoreTab ? 0 : currentSelectedIndex)
    }

    private func rebuildTabs(tabBarController: UITabBarController,
                             willHaveMoreTab: Bool,
                             selectedIndex: Int)
    {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        var viewControllers: [UIViewController] = []

        // Tab 0 - Home (always)
        viewControllers.append(self)

        // Tab 1 - Dynamic based on what's assigned to position2
        if let vc = createViewController(for: .position2, storyboard: storyboard) {
            viewControllers.append(vc)
        }

        // Tab 2 - Snoozer (always)
        let snoozerVC = storyboard.instantiateViewController(withIdentifier: "SnoozerViewController")
        snoozerVC.tabBarItem = UITabBarItem(title: "Snoozer", image: UIImage(systemName: "zzz"), tag: 2)
        viewControllers.append(snoozerVC)

        // Tab 3 - Dynamic based on what's assigned to position4
        if let vc = createViewController(for: .position4, storyboard: storyboard) {
            viewControllers.append(vc)
        }

        // Tab 4 - Settings or More
        if willHaveMoreTab {
            let moreVC = MoreMenuViewController()
            moreVC.tabBarItem = UITabBarItem(title: "More", image: UIImage(systemName: "ellipsis"), tag: 4)
            viewControllers.append(moreVC)
        } else {
            let settingsVC = SettingsViewController()
            settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 4)
            viewControllers.append(settingsVC)
        }

        // Update view controllers without animation to prevent glitches
        tabBarController.setViewControllers(viewControllers, animated: false)

        // Restore selection if valid, otherwise default to home
        let safeIndex = min(selectedIndex, viewControllers.count - 1)
        tabBarController.selectedIndex = max(0, safeIndex)

        updateNightscoutTabState()
    }

    private func getSnoozerTabIndex() -> Int? {
        guard let tabBarController = tabBarController,
              let viewControllers = tabBarController.viewControllers else { return nil }

        for (index, vc) in viewControllers.enumerated() {
            if let _ = vc as? SnoozerViewController {
                return index
            }
        }

        return nil
    }

    private func createViewController(for position: TabPosition, storyboard: UIStoryboard) -> UIViewController? {
        if Storage.shared.alarmsPosition.value == position {
            let vc = storyboard.instantiateViewController(withIdentifier: "AlarmViewController")
            vc.tabBarItem = UITabBarItem(title: "Alarms", image: UIImage(systemName: "alarm"), tag: position == .position2 ? 1 : 3)
            return vc
        }

        if Storage.shared.remotePosition.value == position {
            let vc = storyboard.instantiateViewController(withIdentifier: "RemoteViewController")
            vc.tabBarItem = UITabBarItem(title: "Remote", image: UIImage(systemName: "antenna.radiowaves.left.and.right"), tag: position == .position2 ? 1 : 3)
            return vc
        }

        if Storage.shared.nightscoutPosition.value == position {
            let vc = storyboard.instantiateViewController(withIdentifier: "NightscoutViewController")
            vc.tabBarItem = UITabBarItem(title: "Nightscout", image: UIImage(systemName: "safari"), tag: position == .position2 ? 1 : 3)
            return vc
        }

        return nil
    }

    private func hasItemsInMore() -> Bool {
        return Storage.shared.alarmsPosition.value == .more ||
            Storage.shared.remotePosition.value == .more ||
            Storage.shared.nightscoutPosition.value == .more
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
        UIApplication.shared.isIdleTimerDisabled = Storage.shared.screenlockSwitchState.value

        if Observable.shared.chartSettingsChanged.value {
            updateBGGraphSettings()

            smallGraphHeightConstraint.constant = CGFloat(Storage.shared.smallGraphHeight.value)
            view.layoutIfNeeded()

            Observable.shared.chartSettingsChanged.value = false
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

    @objc override func viewDidAppear(_: Bool) {
        showHideNSDetails()
    }

    func stringFromTimeInterval(interval: TimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }

    private func updateNightscoutTabState() {
        guard let tabBarController = tabBarController,
              let viewControllers = tabBarController.viewControllers else { return }

        let isNightscoutEnabled = !Storage.shared.url.value.isEmpty

        for (index, vc) in viewControllers.enumerated() {
            if vc is NightscoutViewController {
                tabBarController.tabBar.items?[index].isEnabled = isNightscoutEnabled
            }
        }
    }

    func showHideNSDetails() {
        var isHidden = false
        if !IsNightscoutEnabled() {
            isHidden = true
        }

        LoopStatusLabel.isHidden = isHidden
        if IsNotLooping {
            PredictionLabel.isHidden = true
        } else {
            PredictionLabel.isHidden = isHidden
        }
        infoTable.isHidden = isHidden

        if Storage.shared.hideInfoTable.value {
            infoTable.isHidden = true
        }

        updateNightscoutTabState()
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
                if Double(latestBG) >= Storage.shared.highLine.value {
                    color = NSUIColor.systemYellow
                    Observable.shared.bgTextColor.value = .yellow
                } else if Double(latestBG) <= Storage.shared.lowLine.value {
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
                    print(error)
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
                // print("Added missing index \(index) to sortArray")
            }
        }

        // Remove deprecated indices
        sortArray = sortArray.filter { currentValidIndices.contains($0) }

        // Ensure visibleArray is updated with new entries
        if visibleArray.count < currentValidIndices.count {
            for i in visibleArray.count ..< currentValidIndices.count {
                visibleArray.append(InfoType(rawValue: i)?.defaultVisible ?? false)
                // print("Added default visibility for new index \(i)")
            }
        }

        // Trim excess elements if there are more than needed
        if visibleArray.count > currentValidIndices.count {
            visibleArray = Array(visibleArray.prefix(currentValidIndices.count))
            // print("Trimmed visibleArray to match current valid indices")
        }

        Storage.shared.infoSort.value = sortArray
        Storage.shared.infoVisible.value = visibleArray
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
