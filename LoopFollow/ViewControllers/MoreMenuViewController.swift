// LoopFollow
// MoreMenuViewController.swift

import Combine
import SwiftUI
import UIKit

class MoreMenuViewController: UIViewController {
    private var tableView: UITableView!
    private var cancellables = Set<AnyCancellable>()

    struct MenuItem {
        let title: String
        let icon: String
        let subtitle: String?
        let action: () -> Void

        init(title: String, icon: String, subtitle: String? = nil, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.subtitle = subtitle
            self.action = action
        }
    }

    private var menuSections: [[MenuItem]] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Menu"
        view.backgroundColor = .systemBackground

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMenuItems()
        tableView.reloadData()
        Observable.shared.settingsPath.set(NavigationPath())
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if Storage.shared.appearanceMode.value == .system,
           previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
        {
            overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle
        }
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func updateMenuItems() {
        menuSections = []

        // Section 0: Settings (always fixed at top)
        let settingsSection = [
            MenuItem(
                title: "Settings",
                icon: "gear",
                action: { [weak self] in
                    self?.openSettings()
                }
            ),
        ]
        menuSections.append(settingsSection)

        let itemsInMenu = Storage.shared.itemsInMenu()

        if !itemsInMenu.isEmpty {
            var dynamicSection: [MenuItem] = []
            for item in itemsInMenu {
                dynamicSection.append(MenuItem(
                    title: item.displayName,
                    icon: item.icon,
                    action: { [weak self] in
                        self?.openItem(item)
                    }
                ))
            }
            menuSections.append(dynamicSection)
        }

        // Section: Community
        let communitySection = [
            MenuItem(
                title: "LoopFollow Facebook Group",
                icon: "person.2.fill",
                action: { [weak self] in
                    self?.openFacebookGroup()
                }
            ),
        ]
        menuSections.append(communitySection)
    }

    private func openItem(_ item: TabItem) {
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
        let settingsVC = UIHostingController(rootView: SettingsMenuView())
        let navController = UINavigationController(rootViewController: settingsVC)

        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        settingsVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        settingsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettingsModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openAlarmsConfig() {
        let alarmsVC = UIHostingController(rootView: AlarmsContainerView())
        alarmsVC.title = "Alarms"
        let navController = UINavigationController(rootViewController: alarmsVC)

        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        alarmsVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        alarmsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openRemote() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let remoteVC = storyboard.instantiateViewController(withIdentifier: "RemoteViewController")
        let navController = UINavigationController(rootViewController: remoteVC)

        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        remoteVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        remoteVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openNightscout() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nightscoutVC = storyboard.instantiateViewController(withIdentifier: "NightscoutViewController")
        let navController = UINavigationController(rootViewController: nightscoutVC)

        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        nightscoutVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        nightscoutVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openSnoozer() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let snoozerVC = storyboard.instantiateViewController(withIdentifier: "SnoozerViewController")
        let navController = UINavigationController(rootViewController: snoozerVC)

        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        snoozerVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        snoozerVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openTreatments() {
        let treatmentsVC = UIHostingController(rootView: TreatmentsView())
        let navController = UINavigationController(rootViewController: treatmentsVC)

        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        treatmentsVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        // Add a close button
        treatmentsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openAggregatedStats() {
        guard let mainVC = getMainViewController() else {
            presentSimpleAlert(title: "Error", message: "Unable to access data")
            return
        }

        let statsVC = UIHostingController(
            rootView: AggregatedStatsView(viewModel: AggregatedStatsViewModel(mainViewController: mainVC))
        )
        let navController = UINavigationController(rootViewController: statsVC)

        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        statsVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style

        // Add a close button
        statsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openHome() {
        // First check if Home is in the tab bar
        if let tabVC = tabBarController {
            for (index, vc) in (tabVC.viewControllers ?? []).enumerated() {
                if vc is MainViewController {
                    // Home is in the tab bar, switch to it
                    tabVC.selectedIndex = index
                    return
                }
            }
        }

        // Home is in the menu - present the full Home screen as a modal
        let homeModalView = HomeModalView()
        let hostingController = UIHostingController(rootView: homeModalView)

        hostingController.overrideUserInterfaceStyle = Storage.shared.appearanceMode.value.userInterfaceStyle

        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }

    private func openFacebookGroup() {
        if let url = URL(string: "https://www.facebook.com/groups/loopfollowlnl") {
            UIApplication.shared.open(url)
        }
    }

    @objc private func dismissSettingsModal() {
        dismiss(animated: true) {
            // Rebuild tabs after settings is dismissed to apply any tab order changes
            MainViewController.rebuildTabsIfNeeded()
        }
    }

    private func getMainViewController() -> MainViewController? {
        // Try to find MainViewController in the view hierarchy
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

        return nil
    }

    @objc private func dismissModal() {
        dismiss(animated: true)
    }
}

extension MoreMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        return menuSections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuSections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = menuSections[indexPath.section][indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.image = UIImage(systemName: item.icon)

        if let subtitle = item.subtitle {
            config.secondaryText = subtitle
            config.secondaryTextProperties.color = .orange
            config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        }

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        menuSections[indexPath.section][indexPath.row].action()
    }
}
