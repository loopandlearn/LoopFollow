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

    
    

    
    override func viewDidLoad() {
        super.viewDidLoad()

        form
            +++ Section("Urgent Low")
            <<< SwitchRow("urgentLowAlert"){ row in
                row.title = "Active"
                row.tag = "urgentLowAlertActive"
                row.value = UserDefaultsRepository.alertUrgentLowActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertUrgentLowActive.value = value
                }
            <<< SliderRow() { row in
                row.title = "BG"
                row.tag = "urgentLowAlertBG"
                row.steps = 40
                row.value = Float(UserDefaultsRepository.alertUrgentLow.value)
                row.hidden = "$urgentLowAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 40
                cell.slider.maximumValue = 80
            }
            <<< SliderRow() { row in
                row.title = "Default Snooze"
                row.tag = "urgentLowAlertSnooze"
                row.steps = 1
                row.value = Float(UserDefaultsRepository.alertUrgentLowSnooze.value)
                row.hidden = "$urgentLowAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 5
                cell.slider.maximumValue = 10
            }

            +++ Section("Low")
            <<< SwitchRow("lowAlert"){ row in
                row.title = "Active"
                row.tag = "lowAlertActive"
                row.value = UserDefaultsRepository.alertLowActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertLowActive.value = value
                }
            <<< SliderRow() { row in
                row.title = "BG"
                row.tag = "lowAlertBG"
                row.steps = 60
                row.value = Float(UserDefaultsRepository.alertLow.value)
                row.hidden = "$lowAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 40
                cell.slider.maximumValue = 100
            }
            
            <<< SliderRow() { row in
                row.title = "Default Snooze"
                row.tag = "lowAlertSnooze"
                row.steps = 3
                row.value = Float(UserDefaultsRepository.alertLowSnooze.value)
                row.hidden = "$lowAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 5
                cell.slider.maximumValue = 20
            }
        
            +++ Section("High")
            <<< SwitchRow("highAlert"){ row in
                row.title = "Active"
                row.tag = "highAlertActive"
                row.value = UserDefaultsRepository.alertHighActive.value
                }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.alertHighActive.value = value
                }
            <<< SliderRow() { row in
                row.title = "High Alert BG"
                row.tag = "highAlertBG"
                row.steps = 180
                row.value = Float(UserDefaultsRepository.alertHigh.value)
                row.hidden = "$highAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 120
                cell.slider.maximumValue = 300
            }
            
            <<< SliderRow() { row in
                row.title = "Default Snooze"
                row.tag = "highAlertSnooze"
                row.steps = 11
                row.value = Float(UserDefaultsRepository.alertHighSnooze.value)
                row.hidden = "$highAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 10
                cell.slider.maximumValue = 120
            }
        
            +++ Section("Urgent High")
            <<< SwitchRow("urgentHighAlert"){ row in
                    row.title = "Active"
                    row.tag = "urgentHighAlertActive"
                    row.value = UserDefaultsRepository.alertUrgentHighActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertUrgentHighActive.value = value
                    }
                <<< SliderRow() { row in
                    row.title = "Urgent High Alert BG"
                    row.tag = "urgentHighAlertBG"
                    row.steps = 150
                    row.value = Float(UserDefaultsRepository.alertUrgentHigh.value)
                    row.hidden = "$urgentHighAlertActive == false"
                }.cellSetup { cell, row in
                    cell.slider.minimumValue = 200
                    cell.slider.maximumValue = 350
                }
        
            <<< SliderRow() { row in
                row.title = "Default Snooze"
                row.tag = "urgentHighAlertSnooze"
                row.steps = 11
                row.value = Float(UserDefaultsRepository.alertUrgentHighSnooze.value)
                row.hidden = "$urgentHighAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 10
                cell.slider.maximumValue = 120
            }
        
            +++ Section("Missed Readings")
                <<< SwitchRow("missedReadingAlert"){ row in
                        row.title = "Active"
                        row.tag = "missedReadingAlertActive"
                        row.value = UserDefaultsRepository.alertMissedReadingActive.value
                        }.onChange { [weak self] row in
                                guard let value = row.value else { return }
                                UserDefaultsRepository.alertMissedReadingActive.value = value
                        }
                    <<< SliderRow() { row in
                        row.title = "Time"
                        row.tag = "missedReadingTime"
                        row.steps = 10
                        row.value = Float(UserDefaultsRepository.alertMissedReading.value)
                        row.hidden = "$missedReadingAlertActive == false"
                    }.cellSetup { cell, row in
                        cell.slider.minimumValue = 10
                        cell.slider.maximumValue = 60
                    }
            
                <<< SliderRow() { row in
                    row.title = "Default Snooze"
                    row.tag = "missedReadingAlertSnooze"
                    row.steps = 22
                    row.value = Float(UserDefaultsRepository.alertMissedReadingSnooze.value)
                    row.hidden = "$missedReadingAlertActive == false"
                }.cellSetup { cell, row in
                    cell.slider.minimumValue = 10
                    cell.slider.maximumValue = 120
                }
            
        +++ Section("Not Looping")
            <<< SwitchRow("notLoopingAlert"){ row in
                    row.title = "Active"
                    row.tag = "notLoopingAlertActive"
                    row.value = UserDefaultsRepository.alertNotLoopingActive.value
                    }.onChange { [weak self] row in
                            guard let value = row.value else { return }
                            UserDefaultsRepository.alertNotLoopingActive.value = value
                    }
                <<< SliderRow() { row in
                    row.title = "Time"
                    row.tag = "notLoopingTime"
                    row.steps = 10
                    row.value = Float(UserDefaultsRepository.alertNotLooping.value)
                    row.hidden = "$notLoopingAlertActive == false"
                }.cellSetup { cell, row in
                    cell.slider.minimumValue = 10
                    cell.slider.maximumValue = 60
                }
        
            <<< SliderRow() { row in
                row.title = "Default Snooze"
                row.tag = "notLoopingAlertSnooze"
                row.steps = 22
                row.value = Float(UserDefaultsRepository.alertNotLoopingSnooze.value)
                row.hidden = "$notLoopingAlertActive == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 10
                cell.slider.maximumValue = 120
            }
        
    }


}


