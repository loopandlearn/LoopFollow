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
