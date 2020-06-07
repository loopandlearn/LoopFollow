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


    @IBAction func unwindToAlarms(sender: UIStoryboardSegue)
     {
     }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        
        form
            
            +++ Section(header: "Temporary Alert", footer: "Temporary Alert will trigger once and disable. Disabling Alert Below BG will trigger it as a high alert above the BG.")
                       <<< SwitchRow("temporaryAlert"){ row in
                           row.title = "Active"
                           row.tag = "temporaryAlertActive"
                           row.value = UserDefaultsRepository.alertTemporaryActive.value
                           }.onChange { [weak self] row in
                                   guard let value = row.value else { return }
                                   UserDefaultsRepository.alertTemporaryActive.value = value
                           }
                            <<< SwitchRow("temporaryAlertHigh"){ row in
                            row.title = "Alert Below BG"
                            row.tag = "temporaryAlertBelow"
                            row.hidden = "$temporaryAlertActive == false"
                            row.value = UserDefaultsRepository.alertTemporaryBelow.value
                            }.onChange { [weak self] row in
                                    guard let value = row.value else { return }
                                    UserDefaultsRepository.alertTemporaryBelow.value = value
                            }
                       <<< StepperRow() { row in
                           row.title = "BG"
                           row.tag = "temporaryAlertBG"
                           row.cell.stepper.stepValue = 1
                           row.cell.stepper.minimumValue = 40
                           row.cell.stepper.maximumValue = 400
                           row.value = Double(UserDefaultsRepository.alertTemporary.value)
                           row.hidden = "$temporaryAlertActive == false"
                           row.displayValueFor = { value in
                               guard let value = value else { return nil }
                               return "\(Int(value))"
                           }
                       }.onChange { [weak self] row in
                               guard let value = row.value else { return }
                               UserDefaultsRepository.alertTemporary.value = Int(value)
                       }
            
            +++ Section("Main Alerts")
           /* <<< ButtonRow("Create New Alarm") {
                $0.title = $0.tag
                $0.presentationMode = .segueName(segueName: "AlarmEditingViewControllerSegue", onDismiss: nil)
            }*/
            <<< SwitchRow("urgentLowAlert"){ row in
                row.title = "Urgent Low"
                row.tag = "urgentLowAlertActive"
                row.value = UserDefaultsRepository.alertUrgentLowActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertUrgentLowActive.value = value
                }
            <<< StepperRow() { row in
                row.title = "     BG"
                row.tag = "urgentLowAlertBG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 40
                row.cell.stepper.maximumValue = 80
                row.value = Double(UserDefaultsRepository.alertUrgentLow.value)
                row.hidden = "$urgentLowAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLow.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "     Snooze"
                row.tag = "urgentLowAlertSnooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 5
                row.cell.stepper.maximumValue = 15
                row.value = Double(UserDefaultsRepository.alertUrgentLowSnooze.value)
                row.hidden = "$urgentLowAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLowSnooze.value = Int(value)
            }

            <<< SwitchRow("lowAlert"){ row in
                row.title = "Low"
                row.tag = "lowAlertActive"
                row.value = UserDefaultsRepository.alertLowActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertLowActive.value = value
                }
            <<< StepperRow() { row in
                row.title = "     BG"
                row.tag = "lowAlertBG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 40
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.alertLow.value)
                row.hidden = "$lowAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLow.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "     Snooze"
                row.tag = "lowAlertSnooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 5
                row.cell.stepper.maximumValue = 30
                row.value = Double(UserDefaultsRepository.alertLowSnooze.value)
                row.hidden = "$lowAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowSnooze.value = Int(value)
            }
            <<< SwitchRow("highAlert"){ row in
                row.title = "High"
                row.tag = "highAlertActive"
                row.value = UserDefaultsRepository.alertHighActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertHighActive.value = value
                }
            
            <<< StepperRow() { row in
                row.title = "     BG"
                row.tag = "highAlertBG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 120
                row.cell.stepper.maximumValue = 300
                row.value = Double(UserDefaultsRepository.alertHigh.value)
                row.hidden = "$highAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHigh.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "     Persistent For"
                row.tag = "highAlertBGPersistent"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 0
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.alertHighPersistent.value)
                row.hidden = "$highAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighPersistent.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "     Snooze"
                row.tag = "highAlertSnooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 10
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.alertHighSnooze.value)
                row.hidden = "$highAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighSnooze.value = Int(value)
            }
            <<< SwitchRow("urgentHighAlert"){ row in
                    row.title = "Urgent High"
                    row.tag = "urgentHighAlertActive"
                    row.value = UserDefaultsRepository.alertUrgentHighActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertUrgentHighActive.value = value
                    }
            <<< StepperRow() { row in
                row.title = "     BG"
                row.tag = "UrgentHighAlertBG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 120
                row.cell.stepper.maximumValue = 350
                row.value = Double(UserDefaultsRepository.alertUrgentHigh.value)
                row.hidden = "$urgentHighAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentHigh.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "     Snooze"
                row.tag = "urgentHighAlertSnooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 10
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.alertUrgentHighSnooze.value)
                row.hidden = "$urgentHighAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentHighSnooze.value = Int(value)
            }
            
            +++ Section(header: "Fast Rise/Drop Alert", footer: "Alert when BG is changing fast over consecutive readings. Optional: only alert when Dropping and below a specific BG or Rising and above a specific BG")
            <<< SwitchRow("fastChangingAlert"){ row in
                    row.title = "Active"
                    row.tag = "fastChangingAlertActive"
                    row.value = UserDefaultsRepository.alertFastActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertFastActive.value = value
                    }
            <<< StepperRow() { row in
                row.title = "Delta"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 3
                row.cell.stepper.maximumValue = 20
                row.value = Double(UserDefaultsRepository.alertFastDelta.value)
                row.hidden = "$fastChangingAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastDelta.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "# Readings"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 2
                row.cell.stepper.maximumValue = 4
                row.value = Double(UserDefaultsRepository.alertFastReadings.value)
                row.hidden = "$fastChangingAlertActive == false"
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastReadings.value = Int(value)
            }
            <<< SwitchRow("fastUseLimits"){ row in
            row.title = "Use BG Limits"
            row.tag = "fastUseLimitsActive"
            row.hidden = "$fastChangingAlertActive == false"
            row.value = UserDefaultsRepository.alertFastUseLimits.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastUseLimits.value = value
            }
            <<< StepperRow() { row in
                row.title = "Dropping Below BG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 50
                row.cell.stepper.maximumValue = 200
                row.value = Double(UserDefaultsRepository.alertFastLowerLimit.value)
                row.hidden = "$fastChangingAlertActive == false || $fastUseLimitsActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastLowerLimit.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "Rising Above BG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 100
                row.cell.stepper.maximumValue = 300
                row.value = Double(UserDefaultsRepository.alertFastUpperLimit.value)
                row.hidden = "$fastChangingAlertActive == false || $fastUseLimitsActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastUpperLimit.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "Snooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 5
                row.cell.stepper.maximumValue = 60
                row.value = Double(UserDefaultsRepository.alertFastSnooze.value)
                row.hidden = "$fastChangingAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastSnooze.value = Int(value)
            }

            
               
        
            +++ Section(header: "Missed Readings", footer: "Alert when there have been no BG readings for X minutes")
            
                <<< SwitchRow("missedReadingAlert"){ row in
                        row.title = "Active"
                        row.tag = "missedReadingAlertActive"
                        row.value = UserDefaultsRepository.alertMissedReadingActive.value
                        }.onChange { [weak self] row in
                                guard let value = row.value else { return }
                                UserDefaultsRepository.alertMissedReadingActive.value = value
                        }
            
                <<< StepperRow() { row in
                    row.title = "Time"
                    row.tag = "missedReadingTime"
                    row.cell.stepper.stepValue = 5
                    row.cell.stepper.minimumValue = 10
                    row.cell.stepper.maximumValue = 120
                    row.value = Double(UserDefaultsRepository.alertMissedReading.value)
                    row.hidden = "$missedReadingAlertActive == false"
                    row.displayValueFor = { value in
                            guard let value = value else { return nil }
                            return "\(Int(value))"
                        }
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertMissedReading.value = Int(value)
                }
                <<< StepperRow() { row in
                    row.title = "Snooze"
                    row.tag = "missedReadingAlertSnooze"
                    row.cell.stepper.stepValue = 5
                    row.cell.stepper.minimumValue = 10
                    row.cell.stepper.maximumValue = 180
                    row.value = Double(UserDefaultsRepository.alertMissedReadingSnooze.value)
                    row.hidden = "$missedReadingAlertActive == false"
                    row.displayValueFor = { value in
                            guard let value = value else { return nil }
                            return "\(Int(value))"
                        }
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertMissedReadingSnooze.value = Int(value)
                }

            
            +++ Section(header: "Not Looping", footer: "Alert when Loop has not completed a successful Loop for X minutes")
            <<< SwitchRow("notLoopingAlert"){ row in
                    row.title = "Active"
                    row.tag = "notLoopingAlertActive"
                    row.value = UserDefaultsRepository.alertNotLoopingActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertNotLoopingActive.value = value
                    }
            <<< StepperRow() { row in
                row.title = "Time"
                row.tag = "notLoopingAlertTime"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 10
                row.cell.stepper.maximumValue = 60
                row.value = Double(UserDefaultsRepository.alertNotLooping.value)
                row.hidden = "$notLoopingAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLooping.value = Int(value)
            }
            
            <<< SwitchRow("notLoopingUseLimits"){ row in
            row.title = "Use BG Limits"
            row.tag = "notLoopingUseLimitsActive"
            row.hidden = "$notLoopingAlertActive == false"
            row.value = UserDefaultsRepository.alertNotLoopingUseLimits.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingUseLimits.value = value
            }
            <<< StepperRow() { row in
                row.title = "Below BG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 50
                row.cell.stepper.maximumValue = 200
                row.value = Double(UserDefaultsRepository.alertNotLoopingLowerLimit.value)
                row.hidden = "$notLoopingAlertActive == false || $notLoopingUseLimitsActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingLowerLimit.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "Above BG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 100
                row.cell.stepper.maximumValue = 300
                row.value = Double(UserDefaultsRepository.alertNotLoopingUpperLimit.value)
                row.hidden = "$notLoopingAlertActive == false || $notLoopingUseLimitsActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingUpperLimit.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "Snooze"
                row.tag = "notLoopingAlertSnooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 10
                row.cell.stepper.maximumValue = 120
                row.value = Double(UserDefaultsRepository.alertNotLoopingSnooze.value)
                row.hidden = "$notLoopingAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingSnooze.value = Int(value)
            }

        
            +++ Section(header: "Missed Bolus", footer: "Alert after X minutes when carbs are entered with no Bolus. Optional: Ignore low treatment carbs under a certain BG")
            <<< SwitchRow("Missed Bolus"){ row in
                    row.title = "Active"
                    row.tag = "missedBolusAlertActive"
                    row.value = UserDefaultsRepository.alertMissedBolusActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertMissedBolusActive.value = value
                    }
            <<< StepperRow() { row in
                row.title = "Time"
                row.tag = "missedBolusTime"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 5
                row.cell.stepper.maximumValue = 60
                row.value = Double(UserDefaultsRepository.alertMissedBolus.value)
                row.hidden = "$missedBolusAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolus.value = Int(value)
            }
            <<< SwitchRow("Missed Bolus Grams"){ row in
            row.title = "Ignore Low Treatments"
            row.tag = "missedBolusLowGramsActive"
                row.hidden = "$missedBolusAlertActive == false"
            row.value = UserDefaultsRepository.alertMissedBolusLowGramsActive.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusLowGramsActive.value = value
            }
            
            <<< StepperRow() { row in
                row.title = "Ignore Under Grams"
                row.tag = "missedBolusLowGrams"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 15
                row.value = Double(UserDefaultsRepository.alertMissedBolusLowGrams.value)
                row.hidden = "$missedBolusLowGramsActive == false || $missedBolusAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusLowGrams.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "Ignore Under BG"
                row.tag = "missedBolusLowGramsBG"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 40
                row.cell.stepper.maximumValue = 100
                row.value = Double(UserDefaultsRepository.alertMissedBolusLowGramsBG.value)
                row.hidden = "$missedBolusLowGramsActive == false || $missedBolusAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusLowGramsBG.value = Int(value)
            }
            
            <<< StepperRow() { row in
                row.title = "Snooze"
                row.tag = "missedBolusAlertSnooze"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 5
                row.cell.stepper.maximumValue = 60
                row.value = Double(UserDefaultsRepository.alertMissedBolusSnooze.value)
                row.hidden = "$missedBolusAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusSnooze.value = Int(value)
            }

            
             +++ Section(header: "App Inactive", footer: "Attempt to alert if IOS kills the app in the background")
            <<< SwitchRow("inactiveAlert"){ row in
            row.title = "Active"
            row.tag = "inactiveAlertActive"
            row.value = UserDefaultsRepository.alertAppInactive.value
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertAppInactive.value = value
            }
            
        
        
        +++ Section("Reminder Alerts")
        
            <<< SwitchRow("sageAlert"){ row in
                    row.title = "Sensor Change"
                    row.tag = "sageAlertActive"
                    row.value = UserDefaultsRepository.alertSAGEActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertSAGEActive.value = value
                    }
        
            <<< StepperRow() { row in
                row.title = "          Time"
                row.tag = "sageTime"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertSAGE.value)
                row.hidden = "$sageAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGE.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "          Snooze"
                row.tag = "sageAlertSnoozed"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertSAGESnooze.value)
                row.hidden = "$sageAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGESnooze.value = Int(value)
            }
        <<< LabelRow("sageDescription") { row in
            row.title = "Alert X hours before 10 Day Sensor Change. Values are in Hours."
            row.cell.textLabel?.numberOfLines = 0
            row.cell.backgroundColor = UIColor.systemGroupedBackground
            row.cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        }
        
        <<< SwitchRow("cageAlert"){ row in
                    row.title = "Pump Change"
                    row.tag = "cageAlertActive"
                    row.value = UserDefaultsRepository.alertCAGEActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertCAGEActive.value = value
                    }
        
            <<< StepperRow() { row in
                row.title = "          Time"
                row.tag = "cageTime"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertCAGE.value)
                row.hidden = "$cageAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGE.value = Int(value)
            }
            <<< StepperRow() { row in
                row.title = "          Snooze"
                row.tag = "cageAlertSnoozed"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertCAGESnooze.value)
                row.hidden = "$cageAlertActive == false"
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGESnooze.value = Int(value)
            }
        <<< LabelRow("cageDescription") { row in
            row.title = "Alert X hours before 3 Day Pump Change. Values are in Hours."
            row.cell.textLabel?.numberOfLines = 0
            row.cell.backgroundColor = UIColor.systemGroupedBackground
            row.cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        }
        
    }


}


