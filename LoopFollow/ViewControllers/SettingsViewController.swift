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
        
        
        
        form
        +++ Section(header: "Nightscout Settings", footer: "Changing Nightscout settings requires an app restart.")
        <<< TextRow(){ row in
            row.title = "URL"
            row.placeholder = "https://mycgm.herokuapp.com"
            row.value = UserDefaultsRepository.url.value
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
        }.onChange { row in
            guard let value = row.value else { return }
            // check the format of the URL entered by the user and trim away any spaces or "/" at the end
            var urlNSInput = value.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            if urlNSInput.last == "/" {
                urlNSInput = String(urlNSInput.dropLast())
            }
            UserDefaultsRepository.url.value = urlNSInput.lowercased()
            // set the row value back to the correctly formatted URL so that the user immediately sees how it should have been written
            row.value = UserDefaultsRepository.url.value
        }
        <<< TextRow(){ row in
            row.title = "NS Token"
            row.placeholder = "Leave blank if not using tokens"
            row.value = UserDefaultsRepository.token.value
        }.cellSetup { (cell, row) in
            cell.textField.autocorrectionType = .no
        }.onChange { row in
            if row.value == nil {
                UserDefaultsRepository.token.value = ""
            }
            guard let value = row.value else { return }
            UserDefaultsRepository.token.value = value
        }
        <<< SegmentedRow<String>("units") { row in
            row.title = "Units"
            row.options = ["mg/dL", "mmol/L"]
            row.value = UserDefaultsRepository.units.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.units.value = value
        }
        
        
        buildGeneralSettings()
       // buildAlarmSettings()
        buildGraphSettings()
        buildWatchSettings()
        buildDebugSettings()
        
        
        
        
    }
    
    func buildGeneralSettings() {
        form
            +++ Section("General Settings")
        <<< SwitchRow("colorBGText") { row in
        row.title = "Color Main BG Text"
        row.value = UserDefaultsRepository.colorBGText.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.colorBGText.value = value
            // Force main screen update
            guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
            mainScreen.setBGTextColor()
        }
        <<< SwitchRow("forceDarkMode") { row in
        row.title = "Force Dark Mode (Restart App)"
        row.value = UserDefaultsRepository.forceDarkMode.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.forceDarkMode.value = value
        }
        <<< SwitchRow("persistentNotification") { row in
        row.title = "Persistent Notification"
        row.value = UserDefaultsRepository.persistentNotification.value
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
                UserDefaultsRepository.persistentNotification.value = value
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
        <<< StepperRow("backgroundRefreshFrequency") { row in
            row.title = "Refresh Minutes"
            row.tag = "backgroundRefreshFrequency"
            row.cell.stepper.stepValue = 0.25
            row.cell.stepper.minimumValue = 0.25
            row.cell.stepper.maximumValue = 10
            row.value = Double(UserDefaultsRepository.backgroundRefreshFrequency.value)
            row.hidden = "$backgroundRefresh == false"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.backgroundRefreshFrequency.value = value
        }
            
        <<< SwitchRow("appBadge"){ row in
            row.title = "Display App Badge"
            row.tag = "appBadge"
            row.value = UserDefaultsRepository.appBadge.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.appBadge.value = value
                    // Force main screen update
                    guard let mainScreen = self?.tabBarController!.viewControllers?[0] as? MainViewController else { return }
                    mainScreen.nightscoutLoader(forceLoad: true)
        }
        <<< SwitchRow("speakBG"){ row in
            row.title = "Speak BG"
            row.value = UserDefaultsRepository.speakBG.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.speakBG.value = value
        }
    }
    
    func buildAlarmSettings() {
        form
            +++ Section("Alarm Settings")
         <<< SwitchRow("overrideSystemOutputVolume"){ row in
             row.title = "Override System Volume"
             row.value = UserDefaultsRepository.overrideSystemOutputVolume.value
         }.onChange { [weak self] row in
                     guard let value = row.value else { return }
                     UserDefaultsRepository.overrideSystemOutputVolume.value = value
             }
         <<< StepperRow("forcedOutputVolume") { row in
               row.title = "Volume Level"
             row.cell.stepper.stepValue = 0.05
               row.cell.stepper.minimumValue = 0
               row.cell.stepper.maximumValue = 1
               row.value = Double(UserDefaultsRepository.forcedOutputVolume.value)
               row.hidden = "$overrideSystemOutputVolume == false"
                 row.displayValueFor = { value in
                 guard let value = value else { return nil }
                 return "\(Int(value*100))%"
                 }
           }.onChange { [weak self] row in
                   guard let value = row.value else { return }
                   UserDefaultsRepository.forcedOutputVolume.value = Float(value)
           }
        /* <<< StepperRow("fadeInTimeInterval") { row in
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
         }*/
    }
    
    func buildGraphSettings() {
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
    }
    
    func buildWatchSettings(){
        //array of calendars
        let store = EKEventStore()
        let ekCalendars = store.calendars(for: EKEntityType.event)
        var calendars: [cal] = []
        for i in 0..<ekCalendars.count{
            
            let item = cal(title: ekCalendars[i].title, identifier: ekCalendars[i].calendarIdentifier)
            calendars.append(item)
        }
        
        form
       +++ Section(header: "Watch Settings", footer: "Add the Apple calendar complication to your watch face for BG, Trend, Delta, COB, and IOB updated every 5 minutes. Create a new calendar called 'Loop' and modify the calendar settings in the iPhone Watch App to only display the Loop calendar on your watch. It is important to use a new calendar because this will delete other events on the same calendar. Available variables are: %BG%, %DIRECTION%, %DELTA%, %MINAGO%, %IOB%, %COB%, %BASAL%, %LOOP%, and %OVERRIDE% (only displays the percentage). ** %MINAGO% only displays if it is an old reading")
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
        <<< TextRow("watchLine1"){ row in
            row.title = "Line 1"
            row.hidden = "$writeCalendarEvent == false"
            row.value = UserDefaultsRepository.watchLine1.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.watchLine1.value = value
        }
        <<< TextRow("watchLine2"){ row in
            row.title = "Line 2"
            row.hidden = "$writeCalendarEvent == false"
            row.value = UserDefaultsRepository.watchLine2.value
        }.onChange { row in
            guard let value = row.value else { return }
            UserDefaultsRepository.watchLine2.value = value
        }
    }
 
    func buildDebugSettings() {
        form
            +++ Section("Debug Settings")

        <<< SwitchRow("downloadBasal"){ row in
            row.title = "Download Basal"
            row.value = UserDefaultsRepository.downloadBasal.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.downloadBasal.value = value
            }
            <<< SwitchRow("graphBasal"){ row in
            row.title = "Graph Basal"
            row.value = UserDefaultsRepository.graphBasal.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.graphBasal.value = value
            }
            <<< SwitchRow("downloadBolus"){ row in
                row.title = "Download Bolus"
                row.value = UserDefaultsRepository.downloadBolus.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.downloadBolus.value = value
                }
           <<< SwitchRow("graphBolus"){ row in
               row.title = "Graph Bolus"
               row.value = UserDefaultsRepository.graphBolus.value
           }.onChange { [weak self] row in
                       guard let value = row.value else { return }
                       UserDefaultsRepository.graphBolus.value = value
               }
            <<< SwitchRow("downloadCarbs"){ row in
                row.title = "Download Carbs"
                row.value = UserDefaultsRepository.downloadCarbs.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.downloadCarbs.value = value
                }
              <<< SwitchRow("graphCarbs"){ row in
                  row.title = "Graph Carbs"
                  row.value = UserDefaultsRepository.graphCarbs.value
              }.onChange { [weak self] row in
                          guard let value = row.value else { return }
                          UserDefaultsRepository.graphCarbs.value = value
                  }
            
        <<< SwitchRow("downloadPrediction"){ row in
                 row.title = "Download Prediction"
                 row.value = UserDefaultsRepository.downloadPrediction.value
             }.onChange { [weak self] row in
                         guard let value = row.value else { return }
                         UserDefaultsRepository.downloadPrediction.value = value
                 }
        <<< SwitchRow("graphPrediction"){ row in
            row.title = "Graph Prediction"
            row.value = UserDefaultsRepository.graphPrediction.value
        }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.graphPrediction.value = value
            }
            <<< SwitchRow("debugLog"){ row in
                row.title = "Show Debug Log"
                row.value = UserDefaultsRepository.debugLog.value
            }.onChange { [weak self] row in
                        guard let value = row.value else { return }
                        UserDefaultsRepository.debugLog.value = value
                }
        <<< StepperRow("viewRefreshDelay") { row in
            row.title = "View Refresh Delay"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 30
            row.value = Double(UserDefaultsRepository.viewRefreshDelay.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.viewRefreshDelay.value = Double(value)
        }
    }

}
