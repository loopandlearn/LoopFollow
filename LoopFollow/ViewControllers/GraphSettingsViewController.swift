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

   var appStateController: AppStateController?
   
   override func viewDidLoad()  {
      super.viewDidLoad()
      if UserDefaultsRepository.forceDarkMode.value {
         overrideUserInterfaceStyle = .dark
      }
 
      buildGraphSettings()
    
        showHideNSDetails()
   }
   
    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if UserDefaultsRepository.url.value == "" {
            isHidden = true
            isEnabled = false
        }
        
        if let row1 = form.rowBy(tag: "predictionToLoad") as? StepperRow {
            row1.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row1.evaluateHidden()
        }
        
        if let row2 = form.rowBy(tag: "offsetCarbsBolus") as? SwitchRow {
            row2.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row2.evaluateHidden()
        }
        
        if let row3 = form.rowBy(tag: "overrideDisplayLocation") as? StepperRow {
            row3.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row3.evaluateHidden()
        }
        
        if let row4 = form.rowBy(tag: "showValues") as? SwitchRow {
            row4.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row4.evaluateHidden()
        }
        if let row5 = form.rowBy(tag: "showAbsorption") as? SwitchRow {
            row5.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row5.evaluateHidden()
        }
        
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
                // guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                // mainScreen.updateBGGraphSettings()
                
                // tell main screen that grap needs updating
                if let appState = self!.appStateController {
                   appState.chartSettingsChanged = true
                   appState.chartSettingsChanges |= ChartSettingsChangeEnum.showDotsChanged.rawValue
                }
            }
        <<< SwitchRow("switchRowLines"){ row in
            row.title = "Display Lines"
            row.value = UserDefaultsRepository.showLines.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.showLines.value = value
            // Force main screen update
            //guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            //mainScreen.updateBGGraphSettings()
           
            if let appState = self!.appStateController {
               appState.chartSettingsChanged = true
               appState.chartSettingsChanges |= ChartSettingsChangeEnum.showLinesChanged.rawValue
             }
               
        }
            <<< SwitchRow("offsetCarbsBolus"){ row in
                row.title = "Offset Carb/Bolus Dots"
                row.value = UserDefaultsRepository.offsetCarbsBolus.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.offsetCarbsBolus.value = value
                        
            }
            <<< SwitchRow("showValues"){ row in
                row.title = "Show Carb/Bolus Values"
                row.value = UserDefaultsRepository.showValues.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.showValues.value = value
                        
            }
                <<< SwitchRow("showAbsorption"){ row in
                    row.title = "Show Carb Absorption"
                    row.value = UserDefaultsRepository.showAbsorption.value
                }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.showAbsorption.value = value
                            
                }
            <<< SwitchRow("graphBars"){ row in
                row.title = "Carb/Bolus Bar Graph"
                row.value = UserDefaultsRepository.graphBars.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.graphBars.value = value
                        
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
                //guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                //mainScreen.updateBGGraphSettings()
              
                if let appState = self!.appStateController {
                  appState.chartSettingsChanged = true
                  appState.chartSettingsChanges |= ChartSettingsChangeEnum.minBGValueChanged.rawValue
               }
                
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
            //guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            //mainScreen.updateBGGraphSettings()
            
            // tell main screen to update
            if let appState = self!.appStateController {
               appState.chartSettingsChanged = true
               appState.chartSettingsChanges |= ChartSettingsChangeEnum.lowLineChanged.rawValue
             }
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
            //guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            //mainScreen.updateBGGraphSettings()
            
            // let app state know of the change
            if let appState = self!.appStateController {
               appState.chartSettingsChanged = true
               appState.chartSettingsChanges |= ChartSettingsChangeEnum.highLineChanged.rawValue
             }
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
