// LoopFollow
// MoreMenuViewController.swift

import Combine
import SwiftUI
import UIKit

class MoreMenuViewController: UIViewController {
    private var tableView: UITableView!
    private var cancellables = Set<AnyCancellable>()
    private var fallbackMainViewController: MainViewController?
    var needsTabRebuild = false

    // Build Information state
    private var latestVersion: String?
    private var versionTint: UIColor = .secondaryLabel

    // MARK: - Menu models

    enum MenuItemStyle {
        case navigation
        case action
        case detail(String, UIColor)
        case externalLink
    }

    struct MenuItem {
        let title: String
        let icon: String
        let style: MenuItemStyle
        let action: () -> Void

        init(title: String, icon: String, style: MenuItemStyle = .navigation, action: @escaping () -> Void = {}) {
            self.title = title
            self.icon = icon
            self.style = style
            self.action = action
        }
    }

    struct MenuSection {
        let title: String?
        let items: [MenuItem]
    }

    private var menuSections: [MenuSection] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationItem.title = "Menu"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.backButtonDisplayMode = .minimal

        // Apply appearance mode
        overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle

        // Listen for appearance setting changes
        Storage.shared.appearanceMode.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.overrideUserInterfaceStyle = mode.userInterfaceStyle
            }
            .store(in: &cancellables)

        // Listen for system appearance changes (when in System mode)
        NotificationCenter.default.publisher(for: .appearanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
            }
            .store(in: &cancellables)

        setupTableView()
        updateMenuItems()

        Task { [weak self] in
            await self?.fetchVersionInfo()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        updateMenuItems()
        tableView.reloadData()
        Observable.shared.settingsPath.set(NavigationPath())

        if needsTabRebuild {
            needsTabRebuild = false
            MainViewController.rebuildTabsIfNeeded()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if Storage.shared.appearanceMode.value == .system,
           previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        {
            overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        }
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.contentInsetAdjustmentBehavior = .automatic

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Menu construction

    private func updateMenuItems() {
        let build = BuildDetails.default
        let ver = AppVersionManager().version()

        var sections: [MenuSection] = [
            MenuSection(title: nil, items: [
                MenuItem(title: "Settings", icon: "gearshape") { [weak self] in
                    self?.openSettings()
                },
            ]),
        ]

        sections.append(
            MenuSection(title: "Features", items: TabItem.featureOrder.map { item in
                MenuItem(title: item.displayName, icon: item.icon) { [weak self] in
                    self?.openItem(item)
                }
            })
        )

        sections.append(contentsOf: [
            MenuSection(title: "Logging", items: [
                MenuItem(title: "View Log", icon: "doc.text.magnifyingglass") { [weak self] in
                    self?.openViewLog()
                },
                MenuItem(title: "Share Logs", icon: "square.and.arrow.up", style: .action) { [weak self] in
                    self?.shareLogs()
                },
            ]),

            // Section 3: Support & Community
            MenuSection(title: "Support & Community", items: [
                MenuItem(title: "LoopFollow Docs", icon: "book", style: .externalLink) { [weak self] in
                    self?.openURL("https://loopfollowdocs.org/")
                },
                MenuItem(title: "Loop and Learn Discord", icon: "bubble.left.and.bubble.right", style: .externalLink) { [weak self] in
                    self?.openURL("https://discord.gg/KQgk3gzuYU")
                },
                MenuItem(title: "LoopFollow Facebook Group", icon: "person.2.fill", style: .externalLink) { [weak self] in
                    self?.openURL("https://www.facebook.com/groups/loopfollowlnl")
                },
            ]),

            // Section 4: Build Information
            MenuSection(title: "Build Information", items: {
                var items: [MenuItem] = [
                    MenuItem(title: "Version", icon: "", style: .detail(ver, versionTint)),
                    MenuItem(title: "Latest version", icon: "", style: .detail(latestVersion ?? "Fetching…", .secondaryLabel)),
                ]

                if !(build.isMacApp() || build.isSimulatorBuild()) {
                    items.append(MenuItem(
                        title: build.expirationHeaderString,
                        icon: "",
                        style: .detail(dateTimeUtils.formattedDate(from: build.calculateExpirationDate()), .secondaryLabel)
                    ))
                }

                items.append(MenuItem(
                    title: "Built",
                    icon: "",
                    style: .detail(dateTimeUtils.formattedDate(from: build.buildDate()), .secondaryLabel)
                ))
                items.append(MenuItem(
                    title: "Branch",
                    icon: "",
                    style: .detail(build.branchAndSha, .secondaryLabel)
                ))

                return items
            }()),
        ])

        menuSections = sections
    }

    // MARK: - Version fetching

    private func fetchVersionInfo() async {
        let mgr = AppVersionManager()
        let (latest, newer, blacklisted) = await mgr.checkForNewVersionAsync()
        latestVersion = latest ?? "Unknown"

        let current = mgr.version()
        versionTint = blacklisted ? .systemRed
            : newer ? .systemOrange
            : latest == current ? .systemGreen
            : .secondaryLabel

        await MainActor.run {
            updateMenuItems()
            tableView.reloadData()
        }
    }

    // MARK: - Navigation

    private func openItem(_ item: TabItem) {
        // If the item is in the tab bar, switch to it
        if let tabVC = tabBarController,
           let index = (tabVC.viewControllers ?? []).firstIndex(where: { $0.tabBarItem.title == item.displayName })
        {
            tabVC.selectedIndex = index
            return
        }
        // Otherwise push onto navigation stack
        pushItem(item)
    }

    private func pushItem(_ item: TabItem) {
        switch item {
        case .home:
            openHome()
        case .alarms:
            openAlarmsConfig()
        case .remote:
            openRemote()
        case .nightscout:
            openNightscout()
        case .snoozer:
            openSnoozer()
        case .treatments:
            openTreatments()
        case .stats:
            openAggregatedStats()
        }
    }

    private func openSettings() {
        needsTabRebuild = true
        let settingsView = SettingsMenuView(onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        let settingsVC = NavBarHidingHostingController(rootView: settingsView)
        settingsVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    private func openAlarmsConfig() {
        let alarmsView = AlarmsContainerView(onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        let alarmsVC = NavBarHidingHostingController(rootView: alarmsView)
        alarmsVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(alarmsVC, animated: true)
    }

    private func openRemote() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let remoteVC = storyboard.instantiateViewController(withIdentifier: "RemoteViewController")
        remoteVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(remoteVC, animated: true)
        remoteVC.navigationItem.largeTitleDisplayMode = .never
    }

    private func openNightscout() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nightscoutVC = storyboard.instantiateViewController(withIdentifier: "NightscoutViewController")
        nightscoutVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(nightscoutVC, animated: true)
        nightscoutVC.navigationItem.largeTitleDisplayMode = .never
    }

    private func openSnoozer() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let snoozerVC = storyboard.instantiateViewController(withIdentifier: "SnoozerViewController")
        snoozerVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(snoozerVC, animated: true)
        snoozerVC.navigationItem.largeTitleDisplayMode = .never
    }

    private func openTreatments() {
        let treatmentsView = TreatmentsView(onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        let treatmentsVC = NavBarHidingHostingController(rootView: treatmentsView)
        treatmentsVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(treatmentsVC, animated: true)
    }

    private func openAggregatedStats() {
        guard let mainVC = getMainViewController() else {
            presentSimpleAlert(title: "Error", message: "Unable to access data")
            return
        }

        let statsVC = UIHostingController(
            rootView: AggregatedStatsView(viewModel: AggregatedStatsViewModel(mainViewController: mainVC))
        )
        statsVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(statsVC, animated: true)
    }

    private func openHome() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController") as? MainViewController else { return }
        mainVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        mainVC.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(mainVC, animated: true)
    }

    private func openViewLog() {
        let logView = LogView(onBack: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        })
        let logVC = NavBarHidingHostingController(rootView: logView)
        logVC.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        navigationController?.pushViewController(logVC, animated: true)
    }

    private func shareLogs() {
        let files = LogManager.shared.logFilesForTodayAndYesterday()
        guard !files.isEmpty else {
            presentSimpleAlert(title: "No Logs Available", message: "There are no logs to share.")
            return
        }
        let avc = UIActivityViewController(activityItems: files, applicationActivities: nil)
        present(avc, animated: true)
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Helpers

    private func getMainViewController() -> MainViewController? {
        guard let tabBarController = tabBarController else { return nil }

        for vc in tabBarController.viewControllers ?? [] {
            if let mainVC = vc as? MainViewController {
                return mainVC
            }
            if let navVC = vc as? UINavigationController,
               let mainVC = navVC.viewControllers.first as? MainViewController
            {
                return mainVC
            }
        }

        if let fallbackMainViewController {
            return fallbackMainViewController
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController") as? MainViewController else {
            return nil
        }

        mainVC.isPresentedAsModal = true
        fallbackMainViewController = mainVC
        return mainVC
    }
}

// MARK: - NavBarHidingHostingController

/// A UIHostingController subclass that hides the UIKit navigation bar.
/// Used for SwiftUI views that have their own NavigationStack/NavigationView
/// to prevent double navigation bars when pushed onto a UINavigationController.
private class NavBarHidingHostingController<Content: View>: UIHostingController<Content> {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MoreMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        return menuSections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuSections[section].items.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return menuSections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = menuSections[indexPath.section].items[indexPath.row]

        switch item.style {
        case let .detail(value, color):
            var config = UIListContentConfiguration.valueCell()
            config.text = item.title
            config.secondaryText = value
            config.secondaryTextProperties.color = color
            cell.contentConfiguration = config
            cell.accessoryType = .none
            cell.selectionStyle = .none

        case .externalLink:
            var config = cell.defaultContentConfiguration()
            config.text = item.title
            config.image = UIImage(systemName: item.icon)
            cell.contentConfiguration = config
            let linkImage = UIImageView(image: UIImage(systemName: "arrow.up.right.square"))
            linkImage.tintColor = .tertiaryLabel
            cell.accessoryView = linkImage
            cell.selectionStyle = .default

        case .navigation:
            var config = cell.defaultContentConfiguration()
            config.text = item.title
            config.image = UIImage(systemName: item.icon)
            cell.contentConfiguration = config
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

        case .action:
            var config = cell.defaultContentConfiguration()
            config.text = item.title
            config.image = UIImage(systemName: item.icon)
            cell.contentConfiguration = config
            cell.accessoryView = nil
            cell.accessoryType = .none
            cell.selectionStyle = .default
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = menuSections[indexPath.section].items[indexPath.row]
        if case .detail = item.style { return }
        item.action()
    }
}
