//
//  RemoteSettingsViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-03-22.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka
import EventKit
import EventKitUI

class RemoteSettingsViewController: FormViewController {

    override func viewDidLoad()  {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        buildAdvancedSettings()
    }
    private func buildAdvancedSettings() {
        // Define the section
        let remoteCommandsSection = Section(header: "Twilio Settings", footer: "") {
            $0.hidden = Condition.function(["method"], { form in
                // Retrieve the value of the segmented row
                guard let methodRow = form.rowBy(tag: "method") as? SegmentedRow<String>,
                      let selectedOption = methodRow.value else {
                    return true // Default to hiding if there's no selected value
                }
                // Return true to hide the section if "iOS Shortcuts" is selected
                return selectedOption != "SMS API"
            })
        }

        // Add rows to the section
        remoteCommandsSection 
        <<< TextRow("twilioSID"){ row in
            row.title = "Twilio SID"
            row.value = UserDefaultsRepository.twilioSIDString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.twilioSIDString.value = value
        }
        
        <<< TextRow("twilioSecret"){ row in
            row.title = "Twilio Secret"
            row.value = UserDefaultsRepository.twilioSecretString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.twilioSecretString.value = value
        }
        
        <<< TextRow("twilioFromNumberString"){ row in
            row.title = "Twilio from Number"
            row.value = UserDefaultsRepository.twilioFromNumberString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.twilioFromNumberString.value = value
        }
        
        <<< TextRow("twilioToNumberString"){ row in
            row.title = "Twilio to Number"
            row.value = UserDefaultsRepository.twilioToNumberString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.twilioToNumberString.value = value
        }

        // Add the section to the form
        form
        +++ Section(header: "Remote commands method", footer: "")
       <<< SegmentedRow<String>("method") { row in
           row.title = "Use:"
           row.options = ["iOS Shortcuts", "SMS API"]
           row.value = UserDefaultsRepository.method.value
       }.onChange { row in
           guard let value = row.value else { return }
           UserDefaultsRepository.method.value = value
       }
        
        +++ remoteCommandsSection
        
        +++ Section(header: "Remote Settings", footer: "Add the overrides you would like to be able to choose from in the remote override picker. Separate them by comma + blank space.  Example: Override 1, Override 2, Override 3")
                   
            <<< StepperRow("maxCarbs") { row in
                row.title = "Max Carbs (g)"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 0
                row.cell.stepper.maximumValue = 200
                row.value = Double(UserDefaultsRepository.maxCarbs.value)
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.maxCarbs.value = Int(value)
            }
        
        <<< StepperRow("maxBolus") { row in
            row.title = "Max Bolus (U)"
            row.cell.stepper.stepValue = 0.1
            row.cell.stepper.minimumValue = 0.1
            row.cell.stepper.maximumValue = 50
            row.value = Double(UserDefaultsRepository.maxBolus.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                // Format the value with one fraction
                return String(format: "%.1f", value)
            }
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            UserDefaultsRepository.maxBolus.value = Double(value)
        }
        
        <<< TextRow("overrides"){ row in
            row.title = "Overrides:"
            row.value = UserDefaultsRepository.overrideString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.overrideString.value = value
        }
        
            +++ ButtonRow() {
                $0.title = "DONE"
            }.onCellSelection { (row, arg)  in
                self.dismiss(animated:true, completion: nil)
            }
    }
    

}
