//
//  GraphSettingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Eureka
import EventKit
import EventKitUI

class GraphSettingsViewController: FormViewController {
   override func viewDidLoad()  {
      super.viewDidLoad()
      if UserDefaultsRepository.forceDarkMode.value {
         overrideUserInterfaceStyle = .dark
      }
      buildGraphSettings()
   }
    private func buildGraphSettings() {
        form
            +++ Section("Graph Settings")
            
        <<< SwitchRow("switchRowDots"){ row in
            row.title = "Display Dots"
            row.value = UserDefaultsRepository.showDots.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showDots.value = value
                // Force main screen update
                guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                mainScreen.updateBGGraphSettings()
            }
        <<< SwitchRow("switchRowLines"){ row in
            row.title = "Display Lines"
            row.value = UserDefaultsRepository.showLines.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showLines.value = value
            // Force main screen update
            guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            mainScreen.updateBGGraphSettings()
                    
        }
            <<< SwitchRow("offsetCarbsBolus"){ row in
                row.title = "Offset Carb/Bolus Dots"
                row.value = UserDefaultsRepository.offsetCarbsBolus.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.offsetCarbsBolus.value = value
                        
            }
            <<< StepperRow("predictionToLoad") { row in
                row.title = "Hours of Prediction"
                row.cell.stepper.stepValue = 0.25
                row.cell.stepper.minimumValue = 0.0
                row.cell.stepper.maximumValue = 6.0
                row.value = Double(UserDefaultsRepository.predictionToLoad.value)
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.predictionToLoad.value = value
            }
        <<< StepperRow("minBGScale") { row in
            row.title = "Min BG Scale"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = Double(UserDefaultsRepository.highLine.value)
            row.cell.stepper.maximumValue = 400
            row.value = Double(UserDefaultsRepository.minBGScale.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.minBGScale.value = Float(value)
            }
            <<< StepperRow("minBGValue") { row in
                row.title = "Min BG Display"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = -40
                row.cell.stepper.maximumValue = 40
                row.value = Double(UserDefaultsRepository.minBGValue.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.minBGValue.value = Float(value)
                // Force main screen update
                guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                mainScreen.updateBGGraphSettings()
            }
        <<< StepperRow("minBasalScale") { row in
            row.title = "Min Basal Scale"
            row.cell.stepper.stepValue = 0.5
            row.cell.stepper.minimumValue = 0.5
            row.cell.stepper.maximumValue = 20
            row.value = Double(UserDefaultsRepository.minBasalScale.value)
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.minBasalScale.value = value
        }
        <<< StepperRow("lowLine") { row in
            row.title = "Low BG Display Value"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 40
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.lowLine.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.lowLine.value = Float(value)
            // Force main screen update
            guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            mainScreen.updateBGGraphSettings()
        }
        <<< StepperRow("highLine") { row in
            row.title = "High BG Display Value"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 120
            row.cell.stepper.maximumValue = 400
            row.value = Double(UserDefaultsRepository.highLine.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.highLine.value = Float(value)
            // Force main screen update
            guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            mainScreen.updateBGGraphSettings()
        }
        <<< StepperRow("overrideDisplayLocation") { row in
            row.title = "Override BG Location"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = Double(UserDefaultsRepository.minBGValue.value)
            row.cell.stepper.maximumValue = Double(UserDefaultsRepository.minBGScale.value)
            row.value = Double(UserDefaultsRepository.overrideDisplayLocation.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.overrideDisplayLocation.value = Float(value)
            }
            
       +++ ButtonRow() {
          $0.title = "DONE"
       }.onCellSelection { (row, arg)  in
          self.dismiss(animated:true, completion: nil)
       }
    }
}
