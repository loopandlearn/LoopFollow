//
//  AlarmViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka


/*
 
 
 Temporary code...keep here for long-term to create completely customized alarms.
 
 */

class AlarmEditingViewController: FormViewController {


 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        form
            +++ Section("Alert Settings")
            <<< PickerInputRow<String>("Alert Type"){
                $0.title = "Options"
                $0.options = ["Over BG", "Under BG", "Delta Change", "Missed Reading", "Loop Status", "SAGE", "CAGE", "Missed Bolus", "App Inactive"]
                $0.value = $0.options.first
            }
            <<< StepperRow() { row in
                row.title = "BG"
                row.tag = "bg"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 40
                row.cell.stepper.maximumValue = 400
                row.value = 100
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }
            <<< StepperRow() { row in
                row.title = "Persistent (Minutes)"
                row.tag = "time"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 5
                row.cell.stepper.maximumValue = 120
                row.value = 60
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }
            
        
    }


}


