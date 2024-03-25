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

   var appStateController: AppStateController?
    var statusLabelRow: LabelRow!

    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        var isLoopHidden = false;
        if UserDefaultsRepository.url.value == "" || !UserDefaultsRepository.loopUser.value {
            isHidden = true
            isEnabled = false
        }
        
        if let row1 = form.rowBy(tag: "informationDisplaySettings") as? ButtonRow {
            row1.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row1.evaluateHidden()
        }
        
        if UserDefaultsRepository.url.value != "" {
            isEnabled = true
        }
        
        guard let nightscoutTab = self.tabBarController?.tabBar.items![3] else { return }
        nightscoutTab.isEnabled = isEnabled
        
    }
   
    // Determine if the build is from TestFlight
    func isTestFlightBuild() -> Bool {
#if targetEnvironment(simulator)
        return false
#else
        if Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil {
            return false
        }
        guard let receiptName = Bundle.main.appStoreReceiptURL?.lastPathComponent else {
            return false
        }
        return "sandboxReceipt".caseInsensitiveCompare(receiptName) == .orderedSame
#endif
    }
    
    // Get the build date from the build details
    func buildDate() -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE MMM d HH:mm:ss 'UTC' yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        guard let dateString = BuildDetails.default.buildDateString,
              let date = dateFormatter.date(from: dateString) else {
            return nil
        }
        return date
    }
    
    // Calculate the expiration date based on the build type
    func calculateExpirationDate() -> Date {
        if isTestFlightBuild(), let buildDate = buildDate() {
            // For TestFlight, add 90 days to the build date
            return Calendar.current.date(byAdding: .day, value: 90, to: buildDate)!
        } else {
            // For Xcode builds, use the provisioning profile's expiration date
            if let provision = MobileProvision.read() {
                return provision.expirationDate
            } else {
                return Date() // Fallback to current date if unable to read provisioning profile
            }
        }
    }
    
   override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
       UserDefaultsRepository.showNS.value = false
       UserDefaultsRepository.showDex.value = false
    
       let expiration = calculateExpirationDate()
                        
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
           row.value = UserDefaultsRepository.url.value
           row.hidden = "$showNS == false"
       }.cellSetup { (cell, row) in
           cell.textField.autocorrectionType = .no
           cell.textField.autocapitalizationType = .none
       }.onChange { row in
           guard let value = row.value else {
               UserDefaultsRepository.url.value = ""
               self.showHideNSDetails()
               return }
           // check the format of the URL entered by the user and trim away any spaces or "/" at the end
           var urlNSInput = value.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
           if urlNSInput.last == "/" {
               urlNSInput = String(urlNSInput.dropLast())
           }
           UserDefaultsRepository.url.value = urlNSInput.lowercased()
           // set the row value back to the correctly formatted URL so that the user immediately sees how it should have been written
           row.value = UserDefaultsRepository.url.value
           self.showHideNSDetails()
           globalVariables.nsVerifiedAlert = 0
           
           // Verify Nightscout URL and token
           self.checkNightscoutStatus()
       }
       <<< TextRow() { row in
           row.title = "NS Token"
           row.placeholder = "Leave blank if not using tokens"
           row.value = UserDefaultsRepository.token.value
           row.hidden = "$showNS == false"
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
           globalVariables.nsVerifiedAlert = 0
           
           // Verify Nightscout URL and token
           self.checkNightscoutStatus()
       }
       <<< LabelRow() { row in
           row.title = "NS Status"
           row.value = "Checking..."
           statusLabelRow = row
           row.hidden = "$showNS == false"
       }
       <<< SwitchRow("loopUser"){ row in
           row.title = "Download Loop/iAPS Data"
           row.tag = "loopUser"
           row.value = UserDefaultsRepository.loopUser.value
           row.hidden = "$showNS == false"
       }.onChange { [weak self] row in
                   guard let value = row.value else { return }
                   UserDefaultsRepository.loopUser.value = value
           }
        
       <<< SwitchRow("showDex"){ row in
       row.title = "Show Dexcom Settings"
       row.value = UserDefaultsRepository.showDex.value
       }.onChange { [weak self] row in
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
            globalVariables.dexVerifiedAlert = 0
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
            globalVariables.dexVerifiedAlert = 0
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
            <<< LabelRow("Clear Images"){ row in
                row.title = "Delete Watch Face Images"
            }.onCellSelection{ cell,row  in
                if UserDefaultsRepository.saveImage.value {
                    guard let mainScreen = self.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                    
                    mainScreen.deleteOldImages()
                    mainScreen.saveChartImage()
                }
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

       +++ Section(header: getAppVersion(), footer: "")

       +++ Section(header: "App Expiration", footer: String(expiration.description))

        showHideNSDetails()
       checkNightscoutStatus()
    }
    
    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "App Version: \(version)"
        }
        return "Version Unknown"
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
            statusLabelRow.value = "OK"
            NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
        }
        statusLabelRow.updateCell()
    }
    
    func checkNightscoutStatus() {
        NightscoutUtils.verifyURLAndToken(urlUser: UserDefaultsRepository.url.value, token: UserDefaultsRepository.token.value) { error in
            DispatchQueue.main.async {
                self.updateStatusLabel(error: error)
            }
        }
    }
}
