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
   
   var appStateController: AppStateController?
   
   override func viewDidLoad()  {
      super.viewDidLoad()
      
      if UserDefaultsRepository.forceDarkMode.value {
         overrideUserInterfaceStyle = .dark
      }
      buildGeneralSettings()
   }
   
   private func buildGeneralSettings() {
      form
        +++ Section("App Settings")
        <<< SwitchRow("appBadge"){ row in
            row.title = "Display App Badge"
            row.tag = "appBadge"
            row.value = UserDefaultsRepository.appBadge.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.appBadge.value = value
                    // Force main screen update
                    //guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                    //mainScreen.nightscoutLoader(forceLoad: true)
                    
           // set the appstate to indicate settings change and flags
           if let appState = self!.appStateController {
              appState.generalSettingsChanged = true
              appState.generalSettingsChanges |= GeneralSettingsChangeEnum.appBadgeChange.rawValue
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
        <<< SwitchRow("persistentNotification") { row in
        row.title = "Persistent Notification"
        row.value = UserDefaultsRepository.persistentNotification.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.persistentNotification.value = value
        }
        
        +++ Section("Display Settings")
        <<< SwitchRow("forceDarkMode") { row in
        row.title = "Force Dark Mode (Restart App)"
        row.value = UserDefaultsRepository.forceDarkMode.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.forceDarkMode.value = value
             
        }
        <<< SwitchRow("showStats") { row in
        row.title = "Display Stats"
        row.value = UserDefaultsRepository.showStats.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.showStats.value = value
            
             // set the appstate to indicate settings change and flags
             if let appState = self!.appStateController {
                appState.generalSettingsChanged = true
                appState.generalSettingsChanges |= GeneralSettingsChangeEnum.showStatsChange.rawValue
             }
        }
        <<< SwitchRow("showSmallGraph") { row in
        row.title = "Display Small Graph"
        row.value = UserDefaultsRepository.showSmallGraph.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.showSmallGraph.value = value
             
            // set the appstate to indicate settings change and flags
            if let appState = self!.appStateController {
               appState.generalSettingsChanged = true
               appState.generalSettingsChanges |= GeneralSettingsChangeEnum.showSmallGraphChange.rawValue
            }
        }
        <<< SwitchRow("colorBGText") { row in
        row.title = "Color Main BG Text"
        row.value = UserDefaultsRepository.colorBGText.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.colorBGText.value = value
            // Force main screen update
            //guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            //mainScreen.setBGTextColor()
            
            // set the appstate to indicate settings change and flags
            if let appState = self!.appStateController {
              appState.generalSettingsChanged = true
              appState.generalSettingsChanges |= GeneralSettingsChangeEnum.colorBGTextChange.rawValue
           }
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
