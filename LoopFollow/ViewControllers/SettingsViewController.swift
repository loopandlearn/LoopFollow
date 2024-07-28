//
//  SettingsViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka
import EventKit
import EventKitUI

class SettingsViewController: FormViewController {
    var tokenRow: TextRow?
    var appStateController: AppStateController?
    var statusLabelRow: LabelRow!

    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if !IsNightscoutEnabled() {
            isHidden = true
            isEnabled = false
        }

        if let row1 = form.rowBy(tag: "informationDisplaySettings") as? ButtonRow {
            row1.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row1.evaluateHidden()
        }

        if IsNightscoutEnabled() {
            isEnabled = true
        }

        guard let nightscoutTab = self.tabBarController?.tabBar.items![3] else { return }
        nightscoutTab.isEnabled = isEnabled
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        UserDefaultsRepository.showNS.value = false
        UserDefaultsRepository.showDex.value = false

        let buildDetails = BuildDetails.default
        let formattedBuildDate = dateTimeUtils.formattedDate(from: buildDetails.buildDate())
        let branchAndSha = buildDetails.branchAndSha
        let expiration = dateTimeUtils.formattedDate(from: buildDetails.calculateExpirationDate())
        let expirationHeaderString = buildDetails.expirationHeaderString
        let versionManager = AppVersionManager()
        let version = versionManager.version()

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
        <<< SwitchRow("showNS"){ row in
            row.title = "Show Nightscout Settings"
            row.value = UserDefaultsRepository.showNS.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.showNS.value = value
        }
        <<< TextRow() { row in
            row.title = "URL"
            row.placeholder = "https://mycgm.herokuapp.com"
            row.value = ObservableUserDefaults.shared.url.value
            row.hidden = "$showNS == false"
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
            cell.textField.autocapitalizationType = .none
        }.onChange { row in
            guard let value = row.value else {
                ObservableUserDefaults.shared.url.value = ""
                self.showHideNSDetails()
                return
            }

            var useTokenUrl = false

            // Attempt to handle special case: pasted URL including token
            if let urlComponents = URLComponents(string: value), let queryItems = urlComponents.queryItems {
                if let tokenItem = queryItems.first(where: { $0.name.lowercased() == "token" }) {
                    let tokenPattern = "^[^-\\s]+-[0-9a-fA-F]{16}$"
                    if let token = tokenItem.value, let _ = token.range(of: tokenPattern, options: .regularExpression) {
                        var baseComponents = urlComponents
                        baseComponents.queryItems = nil
                        if let baseURL = baseComponents.string {
                            UserDefaultsRepository.token.value = token
                            self.tokenRow?.value = token
                            self.tokenRow?.updateCell()

                            ObservableUserDefaults.shared.url.value = baseURL
                            row.value = baseURL
                            row.updateCell()
                            useTokenUrl = true
                        }
                    }
                }
            }

            if !useTokenUrl {
                // Normalize input: remove unwanted characters and lowercase
                let filtered = value.replacingOccurrences(of: "[^A-Za-z0-9:/._-]", with: "", options: .regularExpression).lowercased()

                // Further clean-up: Remove trailing slashes
                var cleanURL = filtered
                while cleanURL.count > 8 && cleanURL.last == "/" {
                    cleanURL = String(cleanURL.dropLast())
                }

                ObservableUserDefaults.shared.url.value = cleanURL
                row.value = cleanURL
                row.updateCell()
            }

            self.showHideNSDetails()

            // Verify Nightscout URL and token
            self.checkNightscoutStatus()
        }

        <<< TextRow() { row in
            row.title = "NS Token"
            row.placeholder = "Leave blank if not using tokens"
            row.value = UserDefaultsRepository.token.value
            row.hidden = "$showNS == false"
            self.tokenRow = row
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
            cell.textField.autocapitalizationType = .none
            cell.textField.textContentType = .password
        }.onChange { row in
            if row.value == nil {
                UserDefaultsRepository.token.value = ""
            }
            guard let value = row.value else { return }
            UserDefaultsRepository.token.value = value

            // Verify Nightscout URL and token
            self.checkNightscoutStatus()
        }
        <<< LabelRow() { row in
            row.title = "NS Status"
            row.value = "Checking..."
            statusLabelRow = row
            row.hidden = "$showNS == false"
        }
        <<< SwitchRow("showDex"){ row in
            row.title = "Show Dexcom Settings"
            row.value = UserDefaultsRepository.showDex.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.showDex.value = value
        }
        <<< TextRow(){ row in
            row.title = "User Name"
            row.value = UserDefaultsRepository.shareUserName.value
            row.hidden = "$showDex == false"
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
            cell.textField.autocapitalizationType = .none
        }.onChange { row in
            if row.value == nil {
                UserDefaultsRepository.shareUserName.value = ""
            }
            guard let value = row.value else { return }
            UserDefaultsRepository.shareUserName.value = value
        }
        <<< TextRow(){ row in
            row.title = "Password"
            row.value = UserDefaultsRepository.sharePassword.value
            row.hidden = "$showDex == false"
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
            cell.textField.isSecureTextEntry = true
            cell.textField.autocapitalizationType = .none
        }.onChange { row in
            if row.value == nil {
                UserDefaultsRepository.sharePassword.value = ""
            }
            guard let value = row.value else { return }
            UserDefaultsRepository.sharePassword.value = value
        }
        <<< SegmentedRow<String>("shareServer") { row in
            row.title = "Server"
            row.options = ["US", "NON-US"]
            row.value = UserDefaultsRepository.shareServer.value
            row.hidden = "$showDex == false"
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.shareServer.value = value
        }

        +++ Section("App Settings")

        <<< ButtonRow() {
            $0.title = "General Settings"
            $0.presentationMode = .show(
                controllerProvider: .callback(builder: {
                    let controller = GeneralSettingsViewController()
                    controller.appStateController = self.appStateController
                    return controller
                }
                                             ), onDismiss: nil)
        }
        <<< ButtonRow("graphSettings") {
            $0.title = "Graph Settings"
            $0.presentationMode = .show(
                controllerProvider: .callback(builder: {
                    let controller = GraphSettingsViewController()
                    controller.appStateController = self.appStateController
                    return controller
                }
                                             ), onDismiss: nil)
        }
        <<< ButtonRow("informationDisplaySettings") {
            $0.title = "Information Display Settings"
            $0.presentationMode = .show(
                controllerProvider: .callback(builder: {
                    let controller = InfoDisplaySettingsViewController()
                    controller.appStateController = self.appStateController
                    return controller
                }
                                             ), onDismiss: nil)

        }
        <<< ButtonRow("alarmsSettings") {
            $0.title = "Alarms"
            $0.presentationMode = .show(
                controllerProvider: .callback(builder: {
                    guard let alarmVC = ViewControllerManager.shared.alarmViewController else {
                        fatalError("AlarmViewController should be pre-instantiated and available")
                    }
                    return alarmVC
                }), onDismiss: nil)
        }

        +++ Section("Integrations")
        <<< ButtonRow() {
            $0.title = "Apple Watch and Carplay"
            $0.presentationMode = .show(
                controllerProvider: .callback(builder: {
                    let controller = WatchSettingsViewController()
                    controller.appStateController = self.appStateController
                    return controller
                }
                                             ), onDismiss: nil)

        }

        +++ Section("Advanced Settings")
        <<< ButtonRow() {
            $0.title = "Advanced Settings"
            $0.presentationMode = .show(
                controllerProvider: .callback(builder: {
                    let controller = AdvancedSettingsViewController()
                    controller.appStateController = self.appStateController
                    return controller
                }
                                             ), onDismiss: nil)

        }

        +++ Section("Build Information")
        <<< LabelRow() {
            $0.title = "Version"
            $0.value = version
            $0.tag = "currentVersionRow"
        }
        <<< LabelRow() {
            $0.title = "Latest version"
            $0.value = "Fetching..."
            $0.tag = "latestVersionRow"
        }
        <<< LabelRow() {
            $0.title = expirationHeaderString
            $0.value = expiration
            $0.hidden = Condition(booleanLiteral: isMacApp())
        }
        <<< LabelRow() {
            $0.title = "Built"
            $0.value = formattedBuildDate
        }
        <<< LabelRow() {
            $0.title = "Branch"
            $0.value = branchAndSha
        }

        showHideNSDetails()
        checkNightscoutStatus()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refreshVersionInfo()
        checkNightscoutStatus()
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

    func isMacApp() -> Bool {
#if targetEnvironment(macCatalyst)
        return true
#else
        return false
#endif
    }

    func updateStatusLabel(error: NightscoutUtils.NightscoutError?) {
        if let error = error {
            switch error {
            case .invalidURL:
                statusLabelRow.value = "Invalid URL"
            case .networkError:
                statusLabelRow.value = "Network Error"
            case .invalidToken:
                statusLabelRow.value = "Invalid Token"
            case .tokenRequired:
                statusLabelRow.value = "Token Required"
            case .siteNotFound:
                statusLabelRow.value = "Site Not Found"
            case .unknown:
                statusLabelRow.value = "Unknown Error"
            case .emptyAddress:
                statusLabelRow.value = "Address Empty"
            }
        } else {
            statusLabelRow.value = "OK (Read\(ObservableUserDefaults.shared.nsWriteAuth.value ? " & Write" : ""))"
            NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
        }
        statusLabelRow.updateCell()
    }

    func checkNightscoutStatus() {
        NightscoutUtils.verifyURLAndToken { error, jwtToken, nsWriteAuth in
            DispatchQueue.main.async {
                ObservableUserDefaults.shared.nsWriteAuth.value = nsWriteAuth

                self.updateStatusLabel(error: error)
            }
        }
    }
}
