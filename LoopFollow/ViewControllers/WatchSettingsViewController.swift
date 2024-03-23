//
//  WatchSettingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Eureka
import EventKit
import EventKitUI

class WatchSettingsViewController: FormViewController {
    
    var appStateController: AppStateController?
    
    override func viewDidLoad()  {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        
        let eventStore = EKEventStore()
        eventStore.requestCalendarAccess { [weak self] (granted, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Update the form based on the calendar access status
                self.buildWatchSettings(hasCalendarAccess: granted)
                self.showHideNSDetails()
            }
        }
    }
    
    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if UserDefaultsRepository.url.value == "" || !UserDefaultsRepository.loopUser.value {
            isHidden = true
            isEnabled = false
        }
        
        let tmpArr = ["IOB", "COB", "BASAL", "LOOP", "OVERRIDE"]
        for i in 0..<tmpArr.count {
            if let row1 = form.rowBy(tag: tmpArr[i]) as? LabelRow {
                row1.hidden = .function(["hide"],  {form in
                    return isHidden
                })
                row1.evaluateHidden()
            }
        }
        
    }

    private func buildWatchSettings(hasCalendarAccess: Bool){
        
        struct cal {
            var title: String
            var identifier: String
        }
        
        //array of calendars
        let store = EKEventStore()
        let ekCalendars = store.calendars(for: EKEntityType.event)
        var calendars: [cal] = []
        for i in 0..<ekCalendars.count{
            
            let item = cal(title: ekCalendars[i].title, identifier: ekCalendars[i].calendarIdentifier)
            calendars.append(item)
        }
        
        form
            +++ Section(header: "Save BG to Calendar", footer: "Add the Apple calendar complication to your Apple Watch face or Carplay to see BG readings. Create a new calendar called 'Follow' and modify the calendar settings in the iPhone Watch/Carplay App to only display the Follow calendar on your watch or car. It is important to use a new calendar because this will delete other events on the same calendar. Edit Line 1 and Line 2 to be displayed using variables below that will be replaced by the values. Other text entered will not be replaced")
            <<< LabelRow() {
                $0.title = "Calendar Access Denied"
                $0.hidden = Condition.function(["hide"], { _ in hasCalendarAccess })
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }
            <<< SwitchRow("writeCalendarEvent"){ row in
                row.title = "Save BG to Calendar"
                row.value = UserDefaultsRepository.writeCalendarEvent.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.writeCalendarEvent.value = value
            }
            <<< PickerInputRow<String>("calendarIdentifier") { row in
                row.title = "Calendar"
                row.options = calendars.map { $0.identifier }
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
                row.value = UserDefaultsRepository.watchLine1.value
            }.onChange { row in
                guard let value = row.value else { return }
                UserDefaultsRepository.watchLine1.value = value
            }
            <<< TextRow("watchLine2"){ row in
                row.title = "Line 2"
                row.value = UserDefaultsRepository.watchLine2.value
            }.onChange { row in
                guard let value = row.value else { return }
                UserDefaultsRepository.watchLine2.value = value
            }
            <<< SwitchRow("saveImage"){ row in
                row.title = "Save Graph Image for Watch Face"
                row.value = UserDefaultsRepository.saveImage.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.saveImage.value = value
            }
            
        
        
            +++ Section(header: "Available Variables", footer: "")
            <<< LabelRow("BG"){ row in
                row.title = "%BG% : Blood Glucose Reading"
            }
            <<< LabelRow("DIRECTION"){ row in
                row.title = "%DIRECTION% : Dexcom Trend Arrow"
            }
            <<< LabelRow("DELTA"){ row in
                row.title = "%DELTA% : +/- From Last Reading"
            }
            <<< LabelRow("IOB"){ row in
                row.title = "%IOB% : Insulin on Board"
            }
            <<< LabelRow("COB"){ row in
                row.title = "%COB% : Carbs on Board"
            }
            <<< LabelRow("BASAL"){ row in
                row.title = "%BASAL% : Current Basal u/hr"
            }
            <<< LabelRow("LOOP"){ row in
                row.title = "%LOOP% : Loop Status Symbol"
            }
            <<< LabelRow("OVERRIDE"){ row in
                row.title = "%OVERRIDE% : Active Override %"
            }
            <<< LabelRow("MINAGO"){ row in
                row.title = "%MINAGO% : Only displays for old readings"
            }
            
            
            +++ ButtonRow() {
                $0.title = "DONE"
            }.onCellSelection { (row, arg)  in
                self.dismiss(animated:true, completion: nil)
        }
    }
    
}
