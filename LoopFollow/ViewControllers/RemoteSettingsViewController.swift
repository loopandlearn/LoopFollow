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
            let maskedSID = String(repeating: "*", count: UserDefaultsRepository.twilioSIDString.value.count)
            row.value = maskedSID
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.twilioSIDString.value = value
        }
        
        <<< TextRow("twilioSecret"){ row in
            row.title = "Twilio Secret"
            let maskedSecret = String(repeating: "*", count: UserDefaultsRepository.twilioSecretString.value.count)
            row.value = maskedSecret
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
        
        let shortcutsSection = Section(header: "Shortcut names • Textstrings examples", footer: "When iOS Shortcuts are selected as Remote command method, the entries made will be forwarded as a text string when you press 'Send Remote Meal/Bolus/Override/Temp Target buttons. (The text strings can be used as input in your shortcuts).\n\nYou need to create and customize your own iOS shortcuts and use the pre defined names listed above.") {
            $0.hidden = Condition.function(["method"], { form in
                // Retrieve the value of the segmented row
                guard let methodRow = form.rowBy(tag: "method") as? SegmentedRow<String>,
                      let selectedOption = methodRow.value else {
                    return true // Default to hiding if there's no selected value
                }
                // Return true to hide the section if "iOS Shortcuts" is selected
                return selectedOption != "iOS Shortcuts"
            })
        }
        
        // Add rows to the section
        shortcutsSection
        
        <<< TextRow("Remote Meal"){ row in
            row.title = ""
            row.value = "Remote Meal • Meal_Carbs_25g_Fat_15g_Protein_10g_Note_🍔"
            row.cellSetup { cell, row in
                cell.textLabel?.font = UIFont.systemFont(ofSize: 10)
            }
        }
        <<< TextRow("Remote Bolus"){ row in
            row.title = ""
            row.value = "Remote Bolus • Bolus_0.6"
            row.cellSetup { cell, row in
                cell.textLabel?.font = UIFont.systemFont(ofSize: 10)
            }
        }
        <<< TextRow("Remote Override"){ row in
            row.title = ""
            row.value = "Remote Override • Override_🎉 Partytime"
            row.cellSetup { cell, row in
                cell.textLabel?.font = UIFont.systemFont(ofSize: 10)
            }
        }
        <<< TextRow("Remote Temp Target"){ row in
            row.title = ""
            row.value = "Remote Temp Target • TempTarget_🏃‍♂️ Exercise"
            row.cellSetup { cell, row in
                cell.textLabel?.font = UIFont.systemFont(ofSize: 10)
            }
        }
        
    <<< TextRow("Remote Custom Action"){ row in
        row.title = ""
        row.value = "Remote Custom Action • Custom_Any custom textstring"
        row.cellSetup { cell, row in
            cell.textLabel?.font = UIFont.systemFont(ofSize: 10)
        }
    }
        
        // Add the section to the form
        form
        +++ Section(header: "Remote commands method", footer: "")
        <<< SegmentedRow<String>("method") { row in
            row.title = ""
            row.options = ["iOS Shortcuts", "SMS API"]
            row.value = UserDefaultsRepository.method.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.method.value = value
        }
        
        +++ remoteCommandsSection
        
        +++ shortcutsSection
        
        +++ Section(header: "Guardrails", footer: "")
        
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
 
        +++ Section(header: "Presets and Customizations", footer: "Add the overrides, temp targets and custom actions you would like to be able to choose from in respective views picker. Separate them by comma + blank space.  Example: Override 1, Override 2, Override 3\nA Custom Action can be any text string you want to send over sms to trigger anything on the receiving iPhone ")
        
        <<< TextRow("overrides"){ row in
            row.title = "Overrides:"
            row.value = UserDefaultsRepository.overrideString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.overrideString.value = value
        }
        
        <<< TextRow("temptargets"){ row in
            row.title = "Temp Targets:"
            row.value = UserDefaultsRepository.tempTargetsString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.tempTargetsString.value = value
        }
        
        <<< TextRow("customactions"){ row in
            row.title = "Custom Actions:"
            row.value = UserDefaultsRepository.customString.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.customString.value = value
        }
        
        +++ ButtonRow() {
            $0.title = "DONE"
        }.onCellSelection { (row, arg)  in
            self.dismiss(animated:true, completion: nil)
        }
    }
}