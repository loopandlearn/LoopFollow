// LoopFollow
// MoreMenuViewController.swift

import SwiftUI
import UIKit

class MoreMenuViewController: UIViewController {
    private var tableView: UITableView!

    struct MenuItem {
        let title: String
        let icon: String
        let action: () -> Void
    }

    private var menuItems: [MenuItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "More"
        view.backgroundColor = .systemBackground

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }

        setupTableView()
        updateMenuItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMenuItems()
        tableView.reloadData()
        Observable.shared.settingsPath.set(NavigationPath())
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
        menuItems = []

        // Always add Settings
        menuItems.append(MenuItem(
            title: "Settings",
            icon: "gear",
            action: { [weak self] in
                self?.openSettings()
            }
        ))

        // Always add Statistics
        menuItems.append(MenuItem(
            title: "Statistics",
            icon: "chart.bar.fill",
            action: { [weak self] in
                self?.openAggregatedStats()
            }
        ))

        // Add items based on their positions
        if Storage.shared.alarmsPosition.value == .more {
            menuItems.append(MenuItem(
                title: "Alarms",
                icon: "alarm",
                action: { [weak self] in
                    self?.openAlarms()
                }
            ))
        }

        if Storage.shared.remotePosition.value == .more {
            menuItems.append(MenuItem(
                title: "Remote",
                icon: "antenna.radiowaves.left.and.right",
                action: { [weak self] in
                    self?.openRemote()
                }
            ))
        }

        if Storage.shared.nightscoutPosition.value == .more {
            menuItems.append(MenuItem(
                title: "Nightscout",
                icon: "safari",
                action: { [weak self] in
                    self?.openNightscout()
                }
            ))
        }
    }

    private func openSettings() {
        let settingsVC = UIHostingController(rootView: SettingsMenuView())
        let navController = UINavigationController(rootViewController: settingsVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            settingsVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        settingsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func openAlarms() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let alarmsVC = storyboard.instantiateViewController(withIdentifier: "AlarmViewController")
        let navController = UINavigationController(rootViewController: alarmsVC)

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            alarmsVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
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

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            remoteVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
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

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            nightscoutVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        nightscoutVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
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

        // Apply dark mode if needed
        if Storage.shared.forceDarkMode.value {
            statsVC.overrideUserInterfaceStyle = .dark
            navController.overrideUserInterfaceStyle = .dark
        }

        // Add a close button
        statsVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissModal)
        )

        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
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
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return menuItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let item = menuItems[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.image = UIImage(systemName: item.icon)
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        menuItems[indexPath.row].action()
    }
}
