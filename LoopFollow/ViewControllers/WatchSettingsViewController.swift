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
   override func viewDidLoad()  {
      super.viewDidLoad()
      if UserDefaultsRepository.forceDarkMode.value {
         overrideUserInterfaceStyle = .dark
      }
      buildWatchSettings()
   }
   
    private func buildWatchSettings(){
    
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
       +++ Section(header: "Watch Settings", footer: "Add the Apple calendar complication to your watch face for BG, Trend, Delta, COB, and //IOB updated every 5 minutes. Create a new calendar called 'Loop' and modify the calendar settings in the iPhone Watch App to only display the Loop calendar on your watch. It is important to use a new calendar because this will delete other events on the same calendar. Available variables are: %BG%, %DIRECTION%, %DELTA%, %MINAGO%, %IOB%, %COB%, %BASAL%, %LOOP%, and %OVERRIDE% (only displays the percentage). ** %MINAGO% only displays if it is an old reading")
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
      +++ ButtonRow() {
          $0.title = "DONE"
       }.onCellSelection { (row, arg)  in
          self.dismiss(animated:true, completion: nil)
       }
    }

}
