//
//  GeneralSetingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Eureka
import EventKit
import EventKitUI

class GeneralSettingsViewController: FormViewController {
   
   override func viewDidLoad()  {
      super.viewDidLoad()
      
      if UserDefaultsRepository.forceDarkMode.value {
         overrideUserInterfaceStyle = .dark
      }
      buildGeneralSettings()
   }
   
   private func buildGeneralSettings() {
      form
        +++ Section("General Settings")
        <<< SwitchRow("colorBGText") { row in
        row.title = "Color Main BG Text"
        row.value = UserDefaultsRepository.colorBGText.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.colorBGText.value = value
            // Force main screen update
            guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            mainScreen.setBGTextColor()
        }
        <<< SwitchRow("forceDarkMode") { row in
        row.title = "Force Dark Mode (Restart App)"
        row.value = UserDefaultsRepository.forceDarkMode.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.forceDarkMode.value = value
        }
        <<< SwitchRow("persistentNotification") { row in
        row.title = "Persistent Notification"
        row.value = UserDefaultsRepository.persistentNotification.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.persistentNotification.value = value
        }
        <<< SwitchRow("screenlockSwitchState") { row in
            row.title = "Keep Screen Active"
            row.value = UserDefaultsRepository.screenlockSwitchState.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                
                if value {
                    UserDefaultsRepository.screenlockSwitchState.value = value
                }
            }
        
        <<< SwitchRow("backgroundRefresh"){ row in
            row.title = "Background Refresh"
            row.tag = "backgroundRefresh"
            row.value = UserDefaultsRepository.backgroundRefresh.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.backgroundRefresh.value = value
            }
        <<< StepperRow("backgroundRefreshFrequency") { row in
            row.title = "Refresh Minutes"
            row.tag = "backgroundRefreshFrequency"
            row.cell.stepper.stepValue = 0.25
            row.cell.stepper.minimumValue = 0.25
            row.cell.stepper.maximumValue = 10
            row.value = Double(UserDefaultsRepository.backgroundRefreshFrequency.value)
            row.hidden = "$backgroundRefresh == false"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.backgroundRefreshFrequency.value = value
        }
            
        <<< SwitchRow("appBadge"){ row in
            row.title = "Display App Badge"
            row.tag = "appBadge"
            row.value = UserDefaultsRepository.appBadge.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.appBadge.value = value
                    // Force main screen update
                    guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                    mainScreen.nightscoutLoader(forceLoad: true)
        }
        <<< SwitchRow("speakBG"){ row in
            row.title = "Speak BG"
            row.value = UserDefaultsRepository.speakBG.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.speakBG.value = value
        }
        
        +++ ButtonRow() {
          $0.title = "DONE"
       }.onCellSelection { (row, arg)  in
          self.dismiss(animated:true, completion: nil)
       }
    }
   
}