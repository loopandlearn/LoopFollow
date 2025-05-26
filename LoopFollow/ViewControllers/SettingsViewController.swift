// LoopFollow
// SettingsViewController.swift
// Created by Jon Fawcett on 2020-06-05.

import Eureka
import EventKit
import EventKitUI
import SwiftUI
import UIKit

class SettingsViewController: FormViewController, NightscoutSettingsViewModelDelegate {
    var tokenRow: TextRow?
    var statusLabelRow: LabelRow!

    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if !IsNightscoutEnabled() {
            isHidden = true
            isEnabled = false
        }

        if let row1 = form.rowBy(tag: "informationDisplaySettings") as? ButtonRow {
            row1.hidden = .function(["hide"]) { _ in
                isHidden
            }
            row1.evaluateHidden()
        }

        if IsNightscoutEnabled() {
            isEnabled = true
        }

        guard let nightscoutTab = tabBarController?.tabBar.items![3] else { return }
        nightscoutTab.isEnabled = isEnabled
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if Storage.shared.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }

        let buildDetails = BuildDetails.default
        let formattedBuildDate = dateTimeUtils.formattedDate(from: buildDetails.buildDate())
        let branchAndSha = buildDetails.branchAndSha
        let expiration = dateTimeUtils.formattedDate(from: buildDetails.calculateExpirationDate())
        let expirationHeaderString = buildDetails.expirationHeaderString
        let versionManager = AppVersionManager()
        let version = versionManager.version()
        let isMacApp = buildDetails.isMacApp()
        let isSimulatorBuild = buildDetails.isSimulatorBuild()

        form
            +++ Section(header: "Data Settings", footer: "")
            <<< SegmentedRow<String>("units") { row in
                row.title = "Units"
                row.options = ["mg/dL", "mmol/L"]
                row.value = UserDefaultsRepository.units.value
            }.onChange { row in
                guard let value = row.value else { return }
                UserDefaultsRepository.units.value = value
            }
            <<< ButtonRow("nightscout") {
                $0.title = "Nightscout Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentNightscoutSettingsView()
                        return UIViewController()
                    }), onDismiss: nil
                )
            }
            <<< ButtonRow("dexcom") {
                $0.title = "Dexcom Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentDexcomSettingsView()
                        return UIViewController()
                    }), onDismiss: nil
                )
            }

            +++ Section("App Settings")

            <<< ButtonRow("backgroundRefreshSettings") {
                $0.title = "Background Refresh Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentBackgroundRefreshSettings()
                        return UIViewController()
                    }),
                    onDismiss: nil
                )
            }

            <<< ButtonRow {
                $0.title = "General Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentGeneralSettings()
                        return UIViewController()
                    }),
                    onDismiss: nil
                )
            }
            <<< ButtonRow("graphSettings") {
                $0.title = "Graph Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentGraphSettings()
                        return UIViewController()
                    }),
                    onDismiss: nil
                )
            }
            <<< ButtonRow("informationDisplaySettings") {
                $0.title = "Information Display Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentInfoDisplaySettings()
                        return UIViewController()
                    }
                    ), onDismiss: nil
                )
            }

            <<< ButtonRow("alarmsList") {
                $0.title = "Alarms"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentAlarmList()
                        return UIViewController()
                    }),
                    onDismiss: nil
                )
            }

            <<< ButtonRow("alarmsSettings") {
                $0.title = "Alarm Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentAlarmSettings()
                        return UIViewController()
                    }),
                    onDismiss: nil
                )
            }

            <<< ButtonRow("remoteSettings") {
                $0.title = "Remote Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentRemoteSettings()
                        return UIViewController()
                    }),
                    onDismiss: nil
                )
            }

            +++ Section("Integrations")
            <<< ButtonRow {
                $0.title = "Calendar"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        let host = UIHostingController(rootView: WatchSettingsView())
                        host.modalPresentationStyle = .formSheet
                        if Storage.shared.forceDarkMode.value {
                            host.overrideUserInterfaceStyle = .dark
                        }
                        return host
                    }),
                    onDismiss: nil
                )
            }
            <<< ButtonRow("contact") {
                $0.title = "Contact"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentContactSettings()
                        return UIViewController()
                    }
                    ), onDismiss: nil
                )
            }
            +++ Section("Advanced Settings")
            <<< ButtonRow {
                $0.title = "Advanced Settings"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentAdvancedSettingsView()
                        return UIViewController()
                    }), onDismiss: nil
                )
            }

            +++ Section("Logging")
            <<< ButtonRow("viewlog") {
                $0.title = "View Log"
                $0.presentationMode = .show(
                    controllerProvider: .callback(builder: {
                        self.presentLogView()
                        return UIViewController()
                    }), onDismiss: nil
                )
            }
            <<< ButtonRow("shareLogs") {
                $0.title = "Share Logs"
                $0.cellSetup { cell, _ in
                    cell.accessibilityIdentifier = "ShareLogsButton"
                }
                $0.onCellSelection { [weak self] _, _ in
                    self?.shareLogs()
                }
            }

            +++ Section("Build Information")
            <<< LabelRow {
                $0.title = "Version"
                $0.value = version
                $0.tag = "currentVersionRow"
            }
            <<< LabelRow {
                $0.title = "Latest version"
                $0.value = "Fetching..."
                $0.tag = "latestVersionRow"
            }
            <<< LabelRow {
                $0.title = expirationHeaderString
                $0.value = expiration
                $0.hidden = Condition(booleanLiteral: isMacApp || isSimulatorBuild)
            }
            <<< LabelRow {
                $0.title = "Built"
                $0.value = formattedBuildDate
            }
            <<< LabelRow {
                $0.title = "Branch"
                $0.value = branchAndSha
            }

        showHideNSDetails()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refreshVersionInfo()
    }

    func refreshVersionInfo() {
        let versionManager = AppVersionManager()
        versionManager.checkForNewVersion { latestVersion, isNewer, isBlacklisted in
            DispatchQueue.main.async {
                if let currentVersionRow = self.form.rowBy(tag: "currentVersionRow") as? LabelRow {
                    currentVersionRow.cell.detailTextLabel?.textColor = self.getColor(isBlacklisted: isBlacklisted, isNewer: isNewer, isCurrent: latestVersion == versionManager.version())
                    currentVersionRow.updateCell()
                }

                if let latestVersionRow = self.form.rowBy(tag: "latestVersionRow") as? LabelRow {
                    latestVersionRow.value = latestVersion ?? "Unknown"
                    latestVersionRow.updateCell()
                }
            }
        }
    }

    private func getColor(isBlacklisted: Bool, isNewer: Bool, isCurrent: Bool) -> UIColor {
        if isBlacklisted {
            return .red
        } else if isNewer {
            return .orange
        } else if isCurrent {
            return .green
        } else {
            return .secondaryLabel
        }
    }

    func presentInfoDisplaySettings() {
        let viewModel = InfoDisplaySettingsViewModel()
        let settingsView = InfoDisplaySettingsView(viewModel: viewModel)

        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentRemoteSettings() {
        let viewModel = RemoteSettingsViewModel()
        let settingsView = RemoteSettingsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentAlarmSettings() {
        let settingsView = AlarmSettingsView()
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentAlarmList() {
        let settingsView = AlarmListView()
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentContactSettings() {
        let viewModel = ContactSettingsViewModel()
        let contactSettingsView = ContactSettingsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: contactSettingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentBackgroundRefreshSettings() {
        let viewModel = BackgroundRefreshSettingsViewModel()
        let settingsView = BackgroundRefreshSettingsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentLogView() {
        let viewModel = LogViewModel()
        let logView = LogView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: logView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentNightscoutSettingsView() {
        let viewModel = NightscoutSettingsViewModel()
        viewModel.delegate = self

        let view = NightscoutSettingsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func nightscoutSettingsDidFinish() {
        showHideNSDetails()
    }

    func presentDexcomSettingsView() {
        let viewModel = DexcomSettingsViewModel()
        let settingsView = DexcomSettingsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentAdvancedSettingsView() {
        let viewModel = AdvancedSettingsViewModel()
        let view = AdvancedSettingsView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }

        present(hostingController, animated: true, completion: nil)
    }

    func presentGeneralSettings() {
        let view = GeneralSettingsView()
        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            hostingController.overrideUserInterfaceStyle = .dark
        }
        present(hostingController, animated: true)
    }

    func presentGraphSettings() {
        let view = GraphSettingsView()
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .formSheet

        if Storage.shared.forceDarkMode.value {
            host.overrideUserInterfaceStyle = .dark
        }

        present(host, animated: true)
    }

    private func shareLogs() {
        let logFilesToShare = LogManager.shared.logFilesForTodayAndYesterday()

        if !logFilesToShare.isEmpty {
            let activityViewController = UIActivityViewController(activityItems: logFilesToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = view
            present(activityViewController, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "No Logs Available", message: "There are no logs to share.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true, completion: nil)
        }
    }
}
