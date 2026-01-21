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
        let action: () -> Void
    }

    struct MenuSection {
        let title: String?
        let items: [MenuItem]
    }

    private var sections: [MenuSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "More"
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
        updateSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Show navigation bar when returning to More menu
        navigationController?.setNavigationBarHidden(false, animated: animated)
        updateSections()
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

    private func updateSections() {
        sections = []

        // Main section - Settings and dynamic items
        var mainItems: [MenuItem] = []

        mainItems.append(MenuItem(
            title: "Settings",
            icon: "gear",
            action: { [weak self] in
                self?.openSettings()
            }
        ))

        if Storage.shared.alarmsPosition.value == .more {
            mainItems.append(MenuItem(
                title: "Alarms",
                icon: "alarm",
                action: { [weak self] in
                    self?.openAlarms()
                }
            ))
        }

        if Storage.shared.remotePosition.value == .more {
            mainItems.append(MenuItem(
                title: "Remote",
                icon: "antenna.radiowaves.left.and.right",
                action: { [weak self] in
                    self?.openRemote()
                }
            ))
        }

        if Storage.shared.nightscoutPosition.value == .more {
            mainItems.append(MenuItem(
                title: "Nightscout",
                icon: "safari",
                action: { [weak self] in
                    self?.openNightscout()
                }
            ))
        }

        sections.append(MenuSection(title: nil, items: mainItems))

        // Community section
        sections.append(MenuSection(
            title: "Community",
            items: [
                MenuItem(
                    title: "LoopFollow Facebook Group",
                    icon: "person.2.fill",
                    action: { [weak self] in
                        self?.openFacebookGroup()
                    }
                ),
            ]
        ))

        // About section
        sections.append(MenuSection(
            title: "About",
            items: [
                MenuItem(
                    title: "About LoopFollow",
                    icon: "info.circle",
                    action: { [weak self] in
                        self?.openAbout()
                    }
                ),
            ]
        ))
    }

    private func openSettings() {
        let settingsVC = UIHostingController(rootView: SettingsMenuView(isModal: false))


        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        settingsVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style


        // Hide UIKit nav bar - SwiftUI's NavigationStack will handle navigation
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    private func openAlarms() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let alarmsVC = storyboard.instantiateViewController(withIdentifier: "AlarmViewController")


        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        alarmsVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style


        navigationController?.pushViewController(alarmsVC, animated: true)
    }

    private func openRemote() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let remoteVC = storyboard.instantiateViewController(withIdentifier: "RemoteViewController")


        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        remoteVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style


        navigationController?.pushViewController(remoteVC, animated: true)
    }

    private func openNightscout() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nightscoutVC = storyboard.instantiateViewController(withIdentifier: "NightscoutViewController")


        // Apply appearance mode
        let style = Storage.shared.appearanceMode.value.userInterfaceStyle
        nightscoutVC.overrideUserInterfaceStyle = style
        navController.overrideUserInterfaceStyle = style


        navigationController?.pushViewController(nightscoutVC, animated: true)
    }

    private func openFacebookGroup() {
        if let url = URL(string: "https://www.facebook.com/groups/loopfollowlnl") {
            UIApplication.shared.open(url)
        }
    }

    private func openAbout() {
        let aboutView = AboutView()
        let hostingController = UIHostingController(rootView: aboutView)
        hostingController.title = "About"

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        navigationController?.pushViewController(hostingController, animated: true)
    }
}

extension MoreMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.image = UIImage(systemName: item.icon)
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        sections[indexPath.section].items[indexPath.row].action()
    }
}
