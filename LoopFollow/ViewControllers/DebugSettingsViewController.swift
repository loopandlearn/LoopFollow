//
//  DebugSettingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Eureka
import EventKit
import EventKitUI

class DebugSettingsViewController: FormViewController {
   override func viewDidLoad()  {
      super.viewDidLoad()
      if UserDefaultsRepository.forceDarkMode.value {
         overrideUserInterfaceStyle = .dark
      }
      buildDebugSettings()
   }
   private func buildDebugSettings() {
        form
            +++ Section("Debug Settings")

        <<< SwitchRow("downloadBasal"){ row in
            row.title = "Download Basal"
            row.value = UserDefaultsRepository.downloadBasal.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.downloadBasal.value = value
            }
            <<< SwitchRow("graphBasal"){ row in
            row.title = "Graph Basal"
            row.value = UserDefaultsRepository.graphBasal.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.graphBasal.value = value
            }
            <<< SwitchRow("downloadBolus"){ row in
                row.title = "Download Bolus"
                row.value = UserDefaultsRepository.downloadBolus.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.downloadBolus.value = value
                }
           <<< SwitchRow("graphBolus"){ row in
               row.title = "Graph Bolus"
               row.value = UserDefaultsRepository.graphBolus.value
           }.onChange { [weak self] row in
                       guard let value = row.value else { return }
                       UserDefaultsRepository.graphBolus.value = value
               }
            <<< SwitchRow("downloadCarbs"){ row in
                row.title = "Download Carbs"
                row.value = UserDefaultsRepository.downloadCarbs.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.downloadCarbs.value = value
                }
              <<< SwitchRow("graphCarbs"){ row in
                  row.title = "Graph Carbs"
                  row.value = UserDefaultsRepository.graphCarbs.value
              }.onChange { [weak self] row in
                          guard let value = row.value else { return }
                          UserDefaultsRepository.graphCarbs.value = value
                  }
            
        <<< SwitchRow("downloadPrediction"){ row in
                 row.title = "Download Prediction"
                 row.value = UserDefaultsRepository.downloadPrediction.value
             }.onChange { [weak self] row in
                         guard let value = row.value else { return }
                         UserDefaultsRepository.downloadPrediction.value = value
                 }
        <<< SwitchRow("graphPrediction"){ row in
            row.title = "Graph Prediction"
            row.value = UserDefaultsRepository.graphPrediction.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.graphPrediction.value = value
            }
            <<< SwitchRow("debugLog"){ row in
                row.title = "Show Debug Log"
                row.value = UserDefaultsRepository.debugLog.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.debugLog.value = value
                }
        <<< StepperRow("viewRefreshDelay") { row in
            row.title = "View Refresh Delay"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 30
            row.value = Double(UserDefaultsRepository.viewRefreshDelay.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.viewRefreshDelay.value = Double(value)
        }
        +++ ButtonRow() {
          $0.title = "DONE"
        }.onCellSelection { (row, arg)  in
          self.dismiss(animated:true, completion: nil)
        }
    }
}
