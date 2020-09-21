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
    
    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if UserDefaultsRepository.url.value == "" {
            isHidden = true
            isEnabled = false
        }
        
        if let row1 = form.rowBy(tag: "informationDisplaySettings") as? ButtonRow {
            row1.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row1.evaluateHidden()
        }
        
        guard let nightscoutTab = self.tabBarController?.tabBar.items![3] else { return }
        nightscoutTab.isEnabled = isEnabled
        
    }
   
   override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
    
        
                        
        form
        +++ Section(header: "Nightscout Settings", footer: "Changing Nightscout settings requires an app restart.")
        <<< TextRow(){ row in
            row.title = "URL"
            row.placeholder = "https://mycgm.herokuapp.com"
            row.value = UserDefaultsRepository.url.value
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
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
            }
        <<< TextRow(){ row in
            row.title = "NS Token"
            row.placeholder = "Leave blank if not using tokens"
            row.value = UserDefaultsRepository.token.value
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
        }.onChange { row in
            if row.value == nil {
                UserDefaultsRepository.token.value = ""
            }
            guard let value = row.value else { return }
            UserDefaultsRepository.token.value = value
            globalVariables.nsVerifiedAlert = 0
        }
        <<< SegmentedRow<String>("units") { row in
            row.title = "Units"
            row.options = ["mg/dL", "mmol/L"]
            row.value = UserDefaultsRepository.units.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.units.value = value
        }
        +++ Section("Dexcom Settings")
        <<< TextRow(){ row in
            row.title = "User Name"
            row.value = UserDefaultsRepository.shareUserName.value
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
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
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
            cell.textField.isSecureTextEntry = true
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
        
       +++ Section("Debug Settings")
        <<< ButtonRow() {
           $0.title = "Configure Debug"
           $0.presentationMode = .show(
               controllerProvider: .callback(builder: {
                  let controller = DebugSettingsViewController()
                  controller.appStateController = self.appStateController
                  return controller
               }
           ), onDismiss: nil)
            
        }
    
        showHideNSDetails()
      
    }
    
    
}
