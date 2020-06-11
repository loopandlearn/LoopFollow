//
//  SettingsViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Eureka
import EventKit
import EventKitUI

class SettingsViewController: FormViewController {

    struct cal {
        var title: String
        var identifier: String
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        
        //array of calendars
        let store = EKEventStore()
        let ekCalendars = store.calendars(for: EKEntityType.event)
        var calendars: [cal] = []
        for i in 0..<ekCalendars.count{
            
            let item = cal(title: ekCalendars[i].title, identifier: ekCalendars[i].calendarIdentifier)
            calendars.append(item)
        }
      
        form +++ Section("Nightscout Settings")
            <<< TextRow(){ row in
                row.title = "URL"
                row.placeholder = "https://mycgm.herokuapp.com"
                row.value = UserDefaultsRepository.url.value
            }.onChange { row in
                guard let value = row.value else { return }
                UserDefaultsRepository.url.value = value.lowercased()
                }
        +++ Section("General Settings")
            <<< SwitchRow("forceDarkMode") { row in
            row.title = "Always Use Dark Mode (Restart App)"
            row.value = UserDefaultsRepository.forceDarkMode.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                
                if value {
                    UserDefaultsRepository.forceDarkMode.value = value
                }
            }
            <<< SwitchRow("screenlockSwitchState") { row in
                row.title = "Keep Screen Active"
                row.value = UserDefaultsRepository.screenlockSwitchState.value
                }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    
                    if value {
                        UserDefaultsRepository.screenlockSwitchState.value = value
                    }
                }
            
            <<< SwitchRow("backgroundRefresh"){ row in
                row.title = "Background Refresh"
                row.tag = "backgroundRefresh"
                row.value = UserDefaultsRepository.backgroundRefresh.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.backgroundRefresh.value = value
                }
            <<< SliderRow() { row in
                row.title = "Refresh Minutes"
                row.tag = "backgroundRefreshFrequency"
                row.steps = 19
                row.value = Float(UserDefaultsRepository.backgroundRefreshFrequency.value)
                row.hidden = "$backgroundRefresh == false"
            }.cellSetup { cell, row in
                cell.slider.minimumValue = 0.5
                cell.slider.maximumValue = 10
            }
            <<< SwitchRow("appBadge"){ row in
                row.title = "Display App Badge"
                row.tag = "appBadge"
                row.value = UserDefaultsRepository.appBadge.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.appBadge.value = value
                }

        +++ Section("Alarm Settings")
            <<< SwitchRow("overrideSystemOutputVolume"){ row in
                row.title = "Override System Volume"
                row.value = UserDefaultsRepository.overrideSystemOutputVolume.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.overrideSystemOutputVolume.value = value
                }
            <<< StepperRow("systemOutputVolume") { row in
                  row.title = "Volume Level"
                row.cell.stepper.stepValue = 0.05
                  row.cell.stepper.minimumValue = 0
                  row.cell.stepper.maximumValue = 1
                  row.value = Double(UserDefaultsRepository.systemOutputVolume.value)
                  row.hidden = "$overrideSystemOutputVolume == false"
                    row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value*100))%"
                    }
              }.onChange { [weak self] row in
                      guard let value = row.value else { return }
                      UserDefaultsRepository.systemOutputVolume.value = Float(value)
              }
            <<< StepperRow("fadeInTimeInterval") { row in
                row.title = "Fade-in Seconds"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 0
                row.cell.stepper.maximumValue = 60
                row.value = Double(UserDefaultsRepository.fadeInTimeInterval.value)
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.fadeInTimeInterval.value = TimeInterval(value)
            }
            
        +++ Section("Graph Settings")
            <<< SwitchRow("switchRowDots"){ row in
                row.title = "Display Dots"
                row.value = UserDefaultsRepository.showDots.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.showDots.value = value
                }
            <<< SwitchRow("switchRowLines"){ row in
                row.title = "Display Lines"
                row.value = UserDefaultsRepository.showLines.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.showLines.value = value
                        
            }
            <<< StepperRow("lowLine") { row in
                row.title = "Low BG Display Value"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 150
                row.cell.stepper.maximumValue = 400
                row.value = Double(UserDefaultsRepository.lowLine.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.lowLine.value = Int(value)
            }
            <<< StepperRow("highLine") { row in
                row.title = "High BG Display Value"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 150
                row.cell.stepper.maximumValue = 400
                row.value = Double(UserDefaultsRepository.highLine.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.highLine.value = Int(value)
            }
        
        
            +++ Section(header: "Watch Settings", footer: "Add the Apple calendar complication to your watch face for BG, Trend, Delta, COB, and IOB updated every 5 minutes. It is recommended to create a new calendar called 'Loop' and modify the calendar settings in the iPhone Watch App to only display the Loop calendar on your watch")
            <<< SwitchRow("writeCalendarEvent"){ row in
                row.title = "BG to Calendar"
                row.value = UserDefaultsRepository.writeCalendarEvent.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.writeCalendarEvent.value = value
                }
            <<< PickerInputRow<String>("calendarIdentifier") { row in
                row.title = "Calendar"
                row.options = calendars.map { $0.identifier }
                row.hidden = "$writeCalendarEvent == false"
                row.value = UserDefaultsRepository.calendarIdentifier.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    let matching = calendars
                    .flatMap { $0 }
                        .filter { $0.identifier.range(of: value) != nil || $0.title.range(of: value) != nil }
                    if matching.count > 0 {

                        return "\(String(matching[0].title))"
                    } else {
                        return " - "
                    }
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.calendarIdentifier.value = value
            }
        
         }
        
        
        
 


}
