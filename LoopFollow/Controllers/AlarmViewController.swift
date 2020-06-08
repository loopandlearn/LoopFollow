//
//  AlarmViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//


import UIKit
import Eureka

class AlarmViewController: FormViewController {
    
    
    func reloadSnoozeTime(key: String, setNil: Bool, value: Date = Date()) {
        
            if let row = form.rowBy(tag: key) as? DateTimeInlineRow {
                if setNil {
                    row.value = nil
                } else {
                   row.value = value
                }
                
                row.reload()
            }
               
    }
    
    func reloadIsSnoozed(key: String, value: Bool) {
        
            if let row = form.rowBy(tag: key) as? SwitchRow {
            row.value = value
            row.reload()
            }
    }
    
   // static let shared = AlarmViewController()

    @IBAction func unwindToAlarms(sender: UIStoryboardSegue)
     {
     }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        buildTemporaryAlert()
        buildUrgentLow()
        buildLow()
        buildHigh()
        buildUrgentHigh()
        buildFastDropAlert()
        buildFastRiseAlert()
        buildMissedReadings()
        buildNotLooping()
        buildMissedBolus()
        buildAppInactive()
        buildSage()
        buildCage()
        
        
    }

    
    func buildTemporaryAlert(){
        form


        +++ Section(header: "Temporary Alert", footer: "Temporary Alert will trigger once and disable. Disabling Alert Below BG will trigger it as a high alert above the BG.")
                   <<< SwitchRow("alertTemporaryActive"){ row in
                       row.title = "Active"
                       row.value = UserDefaultsRepository.alertTemporaryActive.value
                       }.onChange { [weak self] row in
                               guard let value = row.value else { return }
                               UserDefaultsRepository.alertTemporaryActive.value = value
                       }
                        <<< SwitchRow("alertTemporaryBelow"){ row in
                        row.title = "Alert Below BG"
                        row.hidden = "$alertTemporaryActive == false"
                        row.value = UserDefaultsRepository.alertTemporaryBelow.value
                        }.onChange { [weak self] row in
                                guard let value = row.value else { return }
                                UserDefaultsRepository.alertTemporaryBelow.value = value
                        }
                   <<< StepperRow("alertTemporaryBG") { row in
                       row.title = "BG"
                       row.cell.stepper.stepValue = 1
                       row.cell.stepper.minimumValue = 40
                       row.cell.stepper.maximumValue = 400
                       row.value = Double(UserDefaultsRepository.alertTemporaryBG.value)
                       row.hidden = "$alertTemporaryActive == false"
                       row.displayValueFor = { value in
                           guard let value = value else { return nil }
                           return "\(Int(value))"
                       }
                   }.onChange { [weak self] row in
                           guard let value = row.value else { return }
                           UserDefaultsRepository.alertTemporaryBG.value = Int(value)
                   }
    }
    
    func buildUrgentLow(){
        form
            +++ Section(header: "Urgent Low Alert", footer: "Alerts when BG drops below value")
        <<< SwitchRow("alertUrgentLowActive"){ row in
            row.title = "Active"
            row.value = UserDefaultsRepository.alertUrgentLowActive.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLowActive.value = value
            }
        <<< StepperRow("alertUrgentLowBG") { row in
            row.title = "BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 40
            row.cell.stepper.maximumValue = 80
            row.value = Double(UserDefaultsRepository.alertUrgentLowBG.value)
            row.hidden = "$alertUrgentLowActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowBG.value = Int(value)
        }
        <<< StepperRow("alertUrgentLowSnooze") { row in
            row.title = "Default Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 15
            row.value = Double(UserDefaultsRepository.alertUrgentLowSnooze.value)
            row.hidden = "$alertUrgentLowActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertUrgentLowSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertUrgentLowActive == false"
            
            if (UserDefaultsRepository.alertUrgentLowSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertUrgentLowSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowSnoozedTime.value = value
                UserDefaultsRepository.alertUrgentLowIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertUrgentLowIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
            
        <<< SwitchRow("alertUrgentLowIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertUrgentLowIsSnoozed.value
            row.hidden = "$alertUrgentLowActive == false || $alertUrgentLowSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertUrgentLowSnoozedTime.setNil(key: "alertUrgentLowSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertUrgentLowSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildLow(){
        form
            +++ Section(header: "Low Alert", footer: "Alerts when BG drops below value")
        <<< SwitchRow("alertLowActive"){ row in
            row.title = "Active"
            row.value = UserDefaultsRepository.alertLowActive.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowActive.value = value
            }
        <<< StepperRow("alertLowBG") { row in
            row.title = "BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 40
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertLowBG.value)
            row.hidden = "$alertLowActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowBG.value = Int(value)
        }
        <<< StepperRow("alertLowSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 30
            row.value = Double(UserDefaultsRepository.alertLowSnooze.value)
            row.hidden = "$alertLowActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertLowSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertLowActive == false"
           if (UserDefaultsRepository.alertLowSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertLowSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowSnoozedTime.value = value
                UserDefaultsRepository.alertLowIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertLowIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertLowIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertLowIsSnoozed.value
            row.hidden = "$alertLowActive == false || $alertLowSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertLowSnoozedTime.setNil(key: "alertLowSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertLowSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildHigh(){
        form
        +++ Section(header: "High Alert", footer: "Alerts when BG rises above value. If Persistence is set greater than 0, it will not alert until BG has been high for that many minutes.")
        <<< SwitchRow("alertHighActive"){ row in
            row.title = "High"
            row.value = UserDefaultsRepository.alertHighActive.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighActive.value = value
            }
        
        <<< StepperRow("alertHighBG") { row in
            row.title = "BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 120
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertHighBG.value)
            row.hidden = "$alertHighActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighBG.value = Int(value)
        }
        <<< StepperRow("alertHighPersistent") { row in
            row.title = "Persistent For"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 0
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertHighPersistent.value)
            row.hidden = "$alertHighActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighPersistent.value = Int(value)
        }
        <<< StepperRow("alertHighSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 10
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertHighSnooze.value)
            row.hidden = "$alertHighActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertHighSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertHighActive == false"
            if (UserDefaultsRepository.alertHighSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertHighSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighSnoozedTime.value = value
                UserDefaultsRepository.alertHighIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertHighIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertHighIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertHighIsSnoozed.value
            row.hidden = "$alertHighActive == false || $alertHighSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertHighSnoozedTime.setNil(key: "alertHighSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertHighSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildUrgentHigh(){
        form
            +++ Section(header: "Urgent High Alert", footer: "Alerts when BG rises above value.")
        <<< SwitchRow("alertUrgentHighActive"){ row in
                row.title = "Urgent High"
                row.value = UserDefaultsRepository.alertUrgentHighActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertUrgentHighActive.value = value
                }
        <<< StepperRow("alertUrgentHighBG") { row in
            row.title = "BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 120
            row.cell.stepper.maximumValue = 350
            row.value = Double(UserDefaultsRepository.alertUrgentHighBG.value)
            row.hidden = "$alertUrgentHighActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentHighBG.value = Int(value)
        }
        <<< StepperRow("alertUrgentHighSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 10
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertUrgentHighSnooze.value)
            row.hidden = "$alertUrgentHighActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentHighSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertUrgentHighSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertUrgentHighActive == false"
            if (UserDefaultsRepository.alertUrgentHighSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertUrgentHighSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentHighSnoozedTime.value = value
                UserDefaultsRepository.alertUrgentHighIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertUrgentHighIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertUrgentHighIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertUrgentHighIsSnoozed.value
            row.hidden = "$alertUrgentHighActive == false || $alertUrgentHighSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentHighIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertUrgentHighSnoozedTime.setNil(key: "alertUrgentHighSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertUrgentHighSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildFastDropAlert(){
        form
        +++ Section(header: "Fast Drop Alert", footer: "Alert when BG is dropping fast over consecutive readings. Optional: only alert when dropping below a specific BG")
        <<< SwitchRow("alertFastDropActive"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertFastDropActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertFastDropActive.value = value
                }
        <<< StepperRow("alertFastDropDelta") { row in
            row.title = "Delta"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 3
            row.cell.stepper.maximumValue = 20
            row.value = Double(UserDefaultsRepository.alertFastDropDelta.value)
            row.hidden = "$alertFastDropActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropDelta.value = Int(value)
        }
        <<< StepperRow("alertFastDropReadings") { row in
            row.title = "# Readings"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 2
            row.cell.stepper.maximumValue = 4
            row.value = Double(UserDefaultsRepository.alertFastDropReadings.value)
            row.hidden = "$alertFastDropActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropReadings.value = Int(value)
        }
        <<< SwitchRow("alertFastDropUseLimit"){ row in
        row.title = "Use BG Limit"
        row.hidden = "$alertFastDropActive == false"
        row.value = UserDefaultsRepository.alertFastDropUseLimit.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropUseLimit.value = value
        }
    
        <<< StepperRow("alertFastDropBelowBG") { row in
            row.title = "Dropping Below BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 100
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertFastDropBelowBG.value)
            row.hidden = "$alertFastDropActive == false || $alertFastDropUseLimit == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropBelowBG.value = Int(value)
        }
        <<< StepperRow("alertFastDropSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertFastDropSnooze.value)
            row.hidden = "$alertFastDropActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertFastDropSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertFastDropActive == false"
           if (UserDefaultsRepository.alertFastDropSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertFastDropSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropSnoozedTime.value = value
                UserDefaultsRepository.alertFastDropIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertFastDropIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertFastDropIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertFastDropIsSnoozed.value
            row.hidden = "$alertFastDropActive == false || $alertFastDropSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertFastDropSnoozedTime.setNil(key: "alertFastDropSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertFastDropSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildFastRiseAlert(){
        form
        +++ Section(header: "Fast Rise Alert", footer: "Alert when BG is rising fast over consecutive readings. Optional: only alert when rising above a specific BG")
        <<< SwitchRow("alertFastRiseActive"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertFastRiseActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertFastRiseActive.value = value
                }
        <<< StepperRow("alertFastRiseDelta") { row in
            row.title = "Delta"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 3
            row.cell.stepper.maximumValue = 20
            row.value = Double(UserDefaultsRepository.alertFastRiseDelta.value)
            row.hidden = "$alertFastRiseActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseDelta.value = Int(value)
        }
        <<< StepperRow("alertFastRiseReadings") { row in
            row.title = "# Readings"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 2
            row.cell.stepper.maximumValue = 4
            row.value = Double(UserDefaultsRepository.alertFastRiseReadings.value)
            row.hidden = "$alertFastRiseActive == false"
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseReadings.value = Int(value)
        }
        <<< SwitchRow("alertFastRiseUseLimit"){ row in
        row.title = "Use BG Limit"
        row.hidden = "$alertFastRiseActive == false"
        row.value = UserDefaultsRepository.alertFastRiseUseLimit.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseUseLimit.value = value
        }
    
        <<< StepperRow("alertFastRiseAboveBG") { row in
            row.title = "Rising Above BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 100
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertFastRiseAboveBG.value)
            row.hidden = "$alertFastRiseActive == false || $alertFastRiseUseLimit == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseAboveBG.value = Int(value)
        }
        <<< StepperRow("alertFastRiseSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertFastRiseSnooze.value)
            row.hidden = "$alertFastRiseActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertFastRiseSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertFastRiseActive == false"
           if (UserDefaultsRepository.alertFastRiseSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertFastRiseSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseSnoozedTime.value = value
                UserDefaultsRepository.alertFastRiseIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertFastRiseIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertFastRiseIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertFastRiseIsSnoozed.value
            row.hidden = "$alertFastRiseActive == false || $alertFastRiseSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertFastRiseSnoozedTime.setNil(key: "alertFastRiseSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertFastRiseSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildMissedReadings(){
        form
            +++ Section(header: "Missed Readings", footer: "Alert when there have been no BG readings for X minutes")
        
            <<< SwitchRow("alertMissedReadingActive"){ row in
                    row.title = "Active"
                    row.value = UserDefaultsRepository.alertMissedReadingActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertMissedReadingActive.value = value
                    }
        
            <<< StepperRow("alertMissedReading") { row in
                row.title = "Time"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 10
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.alertMissedReading.value)
                row.hidden = "$alertMissedReadingActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReading.value = Int(value)
            }
            <<< StepperRow("alertMissedReadingSnooze") { row in
                row.title = "Snooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 10
                row.cell.stepper.maximumValue = 180
                row.value = Double(UserDefaultsRepository.alertMissedReadingSnooze.value)
                row.hidden = "$alertMissedReadingActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReadingSnooze.value = Int(value)
            }
        <<< DateTimeInlineRow("alertMissedReadingSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertMissedReadingActive == false"
           if (UserDefaultsRepository.alertMissedReadingSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertMissedReadingSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedReadingSnoozedTime.value = value
                UserDefaultsRepository.alertMissedReadingIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertMissedReadingIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertMissedReadingIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertMissedReadingIsSnoozed.value
            row.hidden = "$alertMissedReadingActive == false || $alertMissedReadingSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedReadingIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertMissedReadingSnoozedTime.setNil(key: "alertMissedReadingSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertMissedReadingSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildNotLooping(){
        form
            +++ Section(header: "Not Looping", footer: "Alert when Loop has not completed a successful Loop for X minutes")
        <<< SwitchRow("alertNotLoopingActive"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertNotLoopingActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertNotLoopingActive.value = value
                }
        <<< StepperRow("alertNotLooping") { row in
            row.title = "Time"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 10
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertNotLooping.value)
            row.hidden = "$alertNotLoopingActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLooping.value = Int(value)
        }
        
        <<< SwitchRow("alertNotLoopingUseLimits"){ row in
        row.title = "Use BG Limits"
        row.hidden = "$alertNotLoopingActive == false"
        row.value = UserDefaultsRepository.alertNotLoopingUseLimits.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingUseLimits.value = value
        }
        <<< StepperRow("alertNotLoopingLowerLimit") { row in
            row.title = "Below BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 50
            row.cell.stepper.maximumValue = 200
            row.value = Double(UserDefaultsRepository.alertNotLoopingLowerLimit.value)
            row.hidden = "$alertNotLoopingActive == false || $alertNotLoopingUseLimits == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingLowerLimit.value = Int(value)
        }
        <<< StepperRow("alertNotLoopingUpperLimit") { row in
            row.title = "Above BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 100
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertNotLoopingUpperLimit.value)
            row.hidden = "$alertNotLoopingActive == false || $alertNotLoopingUseLimits == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingUpperLimit.value = Int(value)
        }
        <<< StepperRow("alertNotLoopingSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 10
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertNotLoopingSnooze.value)
            row.hidden = "$alertNotLoopingActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertNotLoopingSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertNotLoopingActive == false"
           if (UserDefaultsRepository.alertNotLoopingSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertNotLoopingSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingSnoozedTime.value = value
                UserDefaultsRepository.alertNotLoopingIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertNotLoopingIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertNotLoopingIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertNotLoopingIsSnoozed.value
            row.hidden = "$alertNotLoopingActive == false || $alertNotLoopingSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertNotLoopingSnoozedTime.setNil(key: "alertNotLoopingSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertNotLoopingSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildMissedBolus(){
        form
            +++ Section(header: "Missed Bolus", footer: "Alert after X minutes when carbs are entered with no Bolus. Optional: Ignore low treatment carbs under a certain BG")
        <<< SwitchRow("alertMissedBolusActive"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertMissedBolusActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertMissedBolusActive.value = value
                }
        <<< StepperRow("alertMissedBolus") { row in
            row.title = "Time"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertMissedBolus.value)
            row.hidden = "$alertMissedBolusActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolus.value = Int(value)
        }
        <<< SwitchRow("alertMissedBolusLowGramsActive"){ row in
        row.title = "Ignore Low Treatments"
            row.hidden = "$alertMissedBolusActive == false"
        row.value = UserDefaultsRepository.alertMissedBolusLowGramsActive.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusLowGramsActive.value = value
        }
        
        <<< StepperRow("alertMissedBolusLowGrams") { row in
            row.title = "Ignore Under Grams"
            row.tag = "missedBolusLowGrams"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 1
            row.cell.stepper.maximumValue = 15
            row.value = Double(UserDefaultsRepository.alertMissedBolusLowGrams.value)
            row.hidden = "$alertMissedBolusLowGramsActive == false || $alertMissedBolusActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusLowGrams.value = Int(value)
        }
        <<< StepperRow("alertMissedBolusLowGramsBG") { row in
            row.title = "Ignore Under BG"
            row.tag = "missedBolusLowGramsBG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 40
            row.cell.stepper.maximumValue = 100
            row.value = Double(UserDefaultsRepository.alertMissedBolusLowGramsBG.value)
            row.hidden = "$alertMissedBolusLowGramsActive == false || $alertMissedBolusActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusLowGramsBG.value = Int(value)
        }
        
        <<< StepperRow("alertMissedBolusSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertMissedBolusSnooze.value)
            row.hidden = "$alertMissedBolusActive == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusSnooze.value = Int(value)
        }
        <<< DateTimeInlineRow("alertMissedBolusSnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertMissedBolusActive == false"
           if (UserDefaultsRepository.alertMissedBolusSnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertMissedBolusSnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusSnoozedTime.value = value
                UserDefaultsRepository.alertMissedBolusIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertMissedBolusIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertMissedBolusIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertMissedBolusIsSnoozed.value
            row.hidden = "$alertMissedBolusActive == false || $alertMissedBolusSnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertMissedBolusSnoozedTime.setNil(key: "alertMissedBolusSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertMissedBolusSnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildAppInactive(){
         form
            +++ Section(header: "App Inactive", footer: "Attempt to alert if IOS kills the app in the background")
        <<< SwitchRow("alertAppInactive"){ row in
        row.title = "Active"
        row.value = UserDefaultsRepository.alertAppInactive.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertAppInactive.value = value
        }
    }
    
    func buildSage(){
            form
                +++ Section(header: "Sensor Change Reminder", footer: "Alert for 10 Day Sensor Change. Values are in Hours.")
        
            <<< SwitchRow("alertSAGEActive"){ row in
                    row.title = "Active"
                    row.value = UserDefaultsRepository.alertSAGEActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertSAGEActive.value = value
                    }
        
            <<< StepperRow("alertSAGE") { row in
                row.title = "Time"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertSAGE.value)
                row.hidden = "$alertSAGEActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGE.value = Int(value)
            }
            <<< StepperRow("alertSAGESnooze") { row in
                row.title = "Snooze"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertSAGESnooze.value)
                row.hidden = "$alertSAGEActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGESnooze.value = Int(value)
            }
        <<< DateTimeInlineRow("alertSAGESnoozedTime") { row in
            row.title = "Snoozed Until"
            row.hidden = "$alertSAGEActive == false"
           if (UserDefaultsRepository.alertSAGESnoozedTime.value != nil) {
                row.value = UserDefaultsRepository.alertSAGESnoozedTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertSAGESnoozedTime.value = value
                UserDefaultsRepository.alertSAGEIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertSAGEIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
        <<< SwitchRow("alertSAGEIsSnoozed"){ row in
            row.title = "Is Snoozed"
            row.value = UserDefaultsRepository.alertSAGEIsSnoozed.value
            row.hidden = "$alertSAGEActive == false || $alertSAGESnoozedTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertSAGEIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertSAGESnoozedTime.setNil(key: "alertSAGESnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertSAGESnoozedTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
    }
    
    func buildCage(){
        form
            +++ Section(header: "Canula Change Reminder", footer: "Alert for Canula Change. Values are in Hours.")
        <<< SwitchRow("alertCAGEActive"){ row in
                    row.title = "Pump Change"
                    row.value = UserDefaultsRepository.alertCAGEActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertCAGEActive.value = value
                    }
        
            <<< StepperRow("alertCAGE") { row in
                row.title = "          Time"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertCAGE.value)
                row.hidden = "$alertCAGEActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGE.value = Int(value)
            }
            <<< StepperRow("alertCAGESnooze") { row in
                row.title = "          Snooze"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertCAGESnooze.value)
                row.hidden = "$alertCAGEActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGESnooze.value = Int(value)
            }
        <<< DateTimeInlineRow("alertCAGESnoozedTime") { row in
                   row.title = "Snoozed Until"
                   row.hidden = "$alertCAGEActive == false"
                  if (UserDefaultsRepository.alertCAGESnoozedTime.value != nil) {
                       row.value = UserDefaultsRepository.alertCAGESnoozedTime.value
                   }
                   row.minuteInterval = 5
                   row.noValueDisplayText = "Not Snoozed"
                   }
                   .onChange { [weak self] row in
                       guard let value = row.value else { return }
                       UserDefaultsRepository.alertCAGESnoozedTime.value = value
                       UserDefaultsRepository.alertCAGEIsSnoozed.value = true
                       let otherRow = self?.form.rowBy(tag: "alertCAGEIsSnoozed") as! SwitchRow
                       otherRow.value = true
                       otherRow.reload()
                   }
                   .onExpandInlineRow { [weak self] cell, row, inlineRow in
                       inlineRow.cellUpdate() { cell, row in
                           cell.datePicker.datePickerMode = .dateAndTime
                       }
                       let color = cell.detailTextLabel?.textColor
                       row.onCollapseInlineRow { cell, _, _ in
                           cell.detailTextLabel?.textColor = color
                       }
                       cell.detailTextLabel?.textColor = cell.tintColor
               }
               <<< SwitchRow("alertCAGEIsSnoozed"){ row in
                   row.title = "Is Snoozed"
                   row.value = UserDefaultsRepository.alertCAGEIsSnoozed.value
                   row.hidden = "$alertCAGEActive == false || $alertCAGESnoozedTime == nil"
               }.onChange { [weak self] row in
                       guard let value = row.value else { return }
                       UserDefaultsRepository.alertCAGEIsSnoozed.value = value
                       if !value {
                           UserDefaultsRepository.alertCAGESnoozedTime.setNil(key: "alertCAGESnoozedTime")
                           let otherRow = self?.form.rowBy(tag: "alertCAGESnoozedTime") as! DateTimeInlineRow
                          otherRow.value = nil
                          otherRow.reload()
                       }
               }
    }


}


