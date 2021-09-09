//
//  AlarmViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//
//
//
//
//





import UIKit
import Eureka

class AlarmViewController: FormViewController {
    var appStateController: AppStateController?
    
    var soundFiles: [String] = [
        "Alarm_Buzzer",
        "Alarm_Clock",
        "Alert_Tone_Busy",
        "Alert_Tone_Ringtone_1",
        "Alert_Tone_Ringtone_2",
        "Alien_Siren",
        "Ambulance",
        "Analog_Watch_Alarm",
        "Big_Clock_Ticking",
        "Burglar_Alarm_Siren_1",
        "Burglar_Alarm_Siren_2",
        "Cartoon_Ascend_Climb_Sneaky",
        "Cartoon_Ascend_Then_Descend",
        "Cartoon_Bounce_To_Ceiling",
        "Cartoon_Dreamy_Glissando_Harp",
        "Cartoon_Fail_Strings_Trumpet",
        "Cartoon_Machine_Clumsy_Loop",
        "Cartoon_Siren",
        "Cartoon_Tip_Toe_Sneaky_Walk",
        "Cartoon_Uh_Oh",
        "Cartoon_Villain_Horns",
        "Cell_Phone_Ring_Tone",
        "Chimes_Glassy",
        "Computer_Magic",
        "CSFX-2_Alarm",
        "Cuckoo_Clock",
        "Dhol_Shuffleloop",
        "Discreet",
        "Early_Sunrise",
        "Emergency_Alarm_Carbon_Monoxide",
        "Emergency_Alarm_Siren",
        "Emergency_Alarm",
        "Ending_Reached",
        "Fly",
        "Ghost_Hover",
        "Good_Morning",
        "Hell_Yeah_Somewhat_Calmer",
        "In_A_Hurry",
        "Indeed",
        "Insistently",
        "Jingle_All_The_Way",
        "Laser_Shoot",
        "Machine_Charge",
        "Magical_Twinkle",
        "Marching_Heavy_Footed_Fat_Elephants",
        "Marimba_Descend",
        "Marimba_Flutter_or_Shake",
        "Martian_Gun",
        "Martian_Scanner",
        "Metallic",
        "Nightguard",
        "Not_Kiddin",
        "Open_Your_Eyes_And_See",
        "Orchestral_Horns",
        "Oringz",
        "Pager_Beeps",
        "Remembers_Me_Of_Asia",
        "Rise_And_Shine",
        "Rush",
        "Sci-Fi_Air_Raid_Alarm",
        "Sci-Fi_Alarm_Loop_1",
        "Sci-Fi_Alarm_Loop_2",
        "Sci-Fi_Alarm_Loop_3",
        "Sci-Fi_Alarm_Loop_4",
        "Sci-Fi_Alarm",
        "Sci-Fi_Computer_Console_Alarm",
        "Sci-Fi_Console_Alarm",
        "Sci-Fi_Eerie_Alarm",
        "Sci-Fi_Engine_Shut_Down",
        "Sci-Fi_Incoming_Message_Alert",
        "Sci-Fi_Spaceship_Message",
        "Sci-Fi_Spaceship_Warm_Up",
        "Sci-Fi_Warning",
        "Signature_Corporate",
        "Siri_Alert_Calibration_Needed",
        "Siri_Alert_Device_Muted",
        "Siri_Alert_Glucose_Dropping_Fast",
        "Siri_Alert_Glucose_Rising_Fast",
        "Siri_Alert_High_Glucose",
        "Siri_Alert_Low_Glucose",
        "Siri_Alert_Missed_Readings",
        "Siri_Alert_Transmitter_Battery_Low",
        "Siri_Alert_Urgent_High_Glucose",
        "Siri_Alert_Urgent_Low_Glucose",
        "Siri_Calibration_Needed",
        "Siri_Device_Muted",
        "Siri_Glucose_Dropping_Fast",
        "Siri_Glucose_Rising_Fast",
        "Siri_High_Glucose",
        "Siri_Low_Glucose",
        "Siri_Missed_Readings",
        "Siri_Transmitter_Battery_Low",
        "Siri_Urgent_High_Glucose",
        "Siri_Urgent_Low_Glucose",
        "Soft_Marimba_Pad_Positive",
        "Soft_Warm_Airy_Optimistic",
        "Soft_Warm_Airy_Reassuring",
        "Store_Door_Chime",
        "Sunny",
        "Thunder_Sound_FX",
        "Time_Has_Come",
        "Tornado_Siren",
        "Two_Turtle_Doves",
        "Unpaved",
        "Wake_Up_Will_You",
        "Win_Gain",
        "Wrong_Answer"
    ]
    
    var alertRepeatOptions: [String] = [
        "Never",
        "Always",
        "At night",
        "During the day"
    ]
    
    var alertPlaySoundOptions: [String] = [
        "Always",
        "At night",
        "During the day",
        "Never"
    ]
    
    var alertAutosnoozeOptions: [String] = [
        "Never",
        "At night",
        "During the day"
    ]

    
    func timeBasedSettings (pickerValue: String) -> (dayTime:Bool, nightTime:Bool) {
        var dayTime = false
        var nightTime = false
        
        if pickerValue.contains("Always") {
            dayTime = true
            nightTime = true
        } else if pickerValue.contains("Never") {
            dayTime = false
            nightTime = false
        }else{
            if pickerValue.contains("night"){
                nightTime = true
            }
            if pickerValue.contains("day"){
                dayTime = true
            }
        }
        return (dayTime, nightTime)
    }

    func timeBasedSettingsNever (pickerValue: String) -> (dayTime:Bool, nightTime:Bool) {
        var dayTime = false
        var nightTime = false
        
        if pickerValue.contains("Never") {
            dayTime = true
            nightTime = true
        }else{
            if pickerValue.contains("night"){
                nightTime = true
            }
            if pickerValue.contains("day"){
                dayTime = true
            }
        }
        return (dayTime, nightTime)
    }
    
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
    
    func reloadMuteTime(key: String, setNil: Bool, value: Date = Date()) {
        
            if let row = form.rowBy(tag: key) as? DateTimeInlineRow {
                if setNil {
                    row.value = nil
                } else {
                   row.value = value
                }
                
                row.reload()
            }
               
    }
    
    func reloadIsMuted(key: String, value: Bool) {
        
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
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        
        
        form
            +++ Section("Select Alert")
          <<< SegmentedRow<String>("bgAlerts"){ row in
                row.title = ""
                row.options = ["Urgent Low", "Low", "High", "Urgent High"]
                   // row.value = "Urgent Low"
        }.onChange { [weak self] row in
            guard let value = row.value else { return }
            let otherRow = self?.form.rowBy(tag: "bgExtraAlerts") as! SegmentedRow<String>
            otherRow.value = nil
            otherRow.reload()
            let otherRow2 = self?.form.rowBy(tag: "otherAlerts") as! SegmentedRow<String>
            otherRow2.value = nil
            otherRow2.reload()
            let otherRow3 = self?.form.rowBy(tag: "otherAlerts2") as! SegmentedRow<String>
            otherRow3.value = nil
            otherRow3.reload()
            let otherRow4 = self?.form.rowBy(tag: "otherAlerts3") as! SegmentedRow<String>
            otherRow4.value = nil
            otherRow4.reload()
            row.value = value
        }
            <<< SegmentedRow<String>("bgExtraAlerts"){ row in
                row.title = ""
                row.options = ["No Readings", "Fast Drop", "Fast Rise", "Temporary"]
                    //row.value = "Missed Readings"
        }.onChange { [weak self] row in
             guard let value = row.value else { return }
            let otherRow = self?.form.rowBy(tag: "bgAlerts") as! SegmentedRow<String>
               otherRow.value = nil
               otherRow.reload()
               let otherRow2 = self?.form.rowBy(tag: "otherAlerts") as! SegmentedRow<String>
               otherRow2.value = nil
               otherRow2.reload()
            let otherRow3 = self?.form.rowBy(tag: "otherAlerts2") as! SegmentedRow<String>
            otherRow3.value = nil
            otherRow3.reload()
            let otherRow4 = self?.form.rowBy(tag: "otherAlerts3") as! SegmentedRow<String>
            otherRow4.value = nil
            otherRow4.reload()
            row.value = value
        }
            <<< SegmentedRow<String>("otherAlerts"){ row in
                row.title = ""
                row.options = ["Not Looping", "Missed Bolus", "SAGE", "CAGE"]
                if UserDefaultsRepository.url.value == "" {
                    row.hidden = true
                }
                
                //row.value = "Not Looping"
        }.onChange { [weak self] row in
             guard let value = row.value else { return }
            let otherRow = self?.form.rowBy(tag: "bgExtraAlerts") as! SegmentedRow<String>
           otherRow.value = nil
           otherRow.reload()
           let otherRow2 = self?.form.rowBy(tag: "bgAlerts") as! SegmentedRow<String>
           otherRow2.value = nil
           otherRow2.reload()
            let otherRow3 = self?.form.rowBy(tag: "otherAlerts2") as! SegmentedRow<String>
            otherRow3.value = nil
            otherRow3.reload()
            let otherRow4 = self?.form.rowBy(tag: "otherAlerts3") as! SegmentedRow<String>
            otherRow4.value = nil
            otherRow4.reload()
            row.value = value
        }
        <<< SegmentedRow<String>("otherAlerts2"){ row in
                row.title = ""
                row.options = ["Override Start", "Override End", "Pump"]
                if UserDefaultsRepository.url.value == "" {
                    row.hidden = true
                }
                //row.value = "Not Looping"
        }.onChange { [weak self] row in
             guard let value = row.value else { return }
            let otherRow = self?.form.rowBy(tag: "bgExtraAlerts") as! SegmentedRow<String>
           otherRow.value = nil
           otherRow.reload()
           let otherRow2 = self?.form.rowBy(tag: "bgAlerts") as! SegmentedRow<String>
           otherRow2.value = nil
           otherRow2.reload()
            let otherRow3 = self?.form.rowBy(tag: "otherAlerts") as! SegmentedRow<String>
            otherRow3.value = nil
            otherRow3.reload()
            let otherRow4 = self?.form.rowBy(tag: "otherAlerts3") as! SegmentedRow<String>
            otherRow4.value = nil
            otherRow4.reload()
            row.value = value
        }
        
        <<< SegmentedRow<String>("otherAlerts3"){ row in
                row.title = ""
                row.options = ["IOB", "COB"]
                if UserDefaultsRepository.url.value == "" {
                    row.hidden = true
                }
                //row.value = "Not Looping"
        }.onChange { [weak self] row in
             guard let value = row.value else { return }
            let otherRow = self?.form.rowBy(tag: "bgExtraAlerts") as! SegmentedRow<String>
           otherRow.value = nil
           otherRow.reload()
           let otherRow2 = self?.form.rowBy(tag: "bgAlerts") as! SegmentedRow<String>
           otherRow2.value = nil
           otherRow2.reload()
            let otherRow3 = self?.form.rowBy(tag: "otherAlerts") as! SegmentedRow<String>
            otherRow3.value = nil
            otherRow3.reload()
            let otherRow4 = self?.form.rowBy(tag: "otherAlerts2") as! SegmentedRow<String>
            otherRow4.value = nil
            otherRow4.reload()
            row.value = value
        }
        

        
        buildUrgentLow()
        buildLow()
        buildHigh()
        buildUrgentHigh()
        
        
        
        buildFastDropAlert()
        buildFastRiseAlert()
        buildMissedReadings()
        
        
        
        buildNotLooping()
        buildMissedBolus()
        buildSage()
        buildCage()
        
        buildTemporaryAlert()
        
        buildOverrideStart()
        buildOverrideEnd()
        buildPump()
        
        buildIOB()
        buildCOB()
        
        buildSnoozeAll()
        buildAppInactive()
        buildAlarmSettings()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showHideNSDetails()
    }
    
    func showHideNSDetails() {
        var isHidden = false
        var isEnabled = true
        if UserDefaultsRepository.url.value == "" {
            isHidden = true
            isEnabled = false
        }
        
        if let row1 = form.rowBy(tag: "otherAlerts") as? SegmentedRow<String> {
            row1.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row1.evaluateHidden()
        }
        if let row2 = form.rowBy(tag: "overrideAlerts") as? SegmentedRow<String> {
            row2.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row2.evaluateHidden()
        }
        if let row3 = form.sectionBy(tag: "quietHourSection") as? Section {
            row3.hidden = .function(["hide"],  {form in
                return isHidden
            })
            row3.evaluateHidden()
        }
        
        guard let nightscoutTab = self.tabBarController?.tabBar.items![3] else { return }
        nightscoutTab.isEnabled = isEnabled
        
    }

    func buildSnoozeAll(){
        form
            +++ Section(header: "Snooze & Mute Options", footer: "Snooze and Mute All Sounds: Snooze All turns everything off, Mute All turns off phone sounds but leaves vibration and iOS notifications on")
        <<< DateTimeInlineRow("alertSnoozeAllTime") { row in
            row.title = "Snooze All Until"
            
            if (UserDefaultsRepository.alertSnoozeAllTime.value != nil) {
                row.value = UserDefaultsRepository.alertSnoozeAllTime.value
            }
            row.minuteInterval = 5
            row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertSnoozeAllTime.value = value
                UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertSnoozeAllIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                    cell.datePicker.preferredDatePickerStyle = .wheels
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
        }
            
        <<< SwitchRow("alertSnoozeAllIsSnoozed"){ row in
            row.title = "All Alerts Snoozed"
            row.value = UserDefaultsRepository.alertSnoozeAllIsSnoozed.value
            row.hidden = "$alertSnoozeAllTime == nil"
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertSnoozeAllTime.setNil(key: "alertSnoozeAllTime")
                    let otherRow = self?.form.rowBy(tag: "alertSnoozeAllTime") as! DateTimeInlineRow
                   otherRow.value = nil
                   otherRow.reload()
                }
        }
        
            <<< DateTimeInlineRow("alertMuteAllTime") { row in
                row.title = "Mute All Until"
                
                if (UserDefaultsRepository.alertMuteAllTime.value != nil) {
                    row.value = UserDefaultsRepository.alertMuteAllTime.value
                }
                row.minuteInterval = 5
                row.noValueDisplayText = "Not Muted"
                }
                .onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMuteAllTime.value = value
                    UserDefaultsRepository.alertMuteAllIsMuted.value = true
                    let otherRow = self?.form.rowBy(tag: "alertMuteAllIsMuted") as! SwitchRow
                    otherRow.value = true
                    otherRow.reload()
                }
                .onExpandInlineRow { [weak self] cell, row, inlineRow in
                    inlineRow.cellUpdate() { cell, row in
                        cell.datePicker.datePickerMode = .dateAndTime
                        cell.datePicker.preferredDatePickerStyle = .wheels
                    }
                    let color = cell.detailTextLabel?.textColor
                    row.onCollapseInlineRow { cell, _, _ in
                        cell.detailTextLabel?.textColor = color
                    }
                    cell.detailTextLabel?.textColor = cell.tintColor
            }
            <<< SwitchRow("alertMuteAllIsMuted"){ row in
                row.title = "All Sounds Muted"
                row.value = UserDefaultsRepository.alertMuteAllIsMuted.value
                row.hidden = "$alertMuteAllTime == nil"
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMuteAllIsMuted.value = value
                    if !value {
                        UserDefaultsRepository.alertMuteAllTime.setNil(key: "alertMuteAllTime")
                        let otherRow = self?.form.rowBy(tag: "alertMuteAllTime") as! DateTimeInlineRow
                       otherRow.value = nil
                       otherRow.reload()
                    }
            }
    }

    func buildTemporaryAlert(){
        form
            
            
            +++ Section(header: "Temporary Alert", footer: "Temporary Alert will trigger once and disable. Disabling Alert Below BG will trigger it as a high alert above the BG.") { row in
                row.hidden = "$bgExtraAlerts != 'Temporary'"
            }
            <<< SwitchRow("alertTemporaryActive"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertTemporaryActive.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertTemporaryActive.value = value
            }
            <<< SwitchRow("alertTemporaryBelow"){ row in
                row.title = "Alert Below BG"
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
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertTemporaryBG.value = Float(value)
            }
            <<< PickerInputRow<String>("alertTemporarySound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertTemporarySound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertTemporarySound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
        }
        <<< SwitchRow("alertTemporaryRepeat"){ row in
        row.title = "Repeat Sound"
        row.value = UserDefaultsRepository.alertTemporaryBGRepeat.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertTemporaryBGRepeat.value = value
        }
    }
    
    func buildUrgentLow(){
        form
            +++ Section(header: "Urgent Low Alert", footer: "Alerts when BG drops below value") { row in
                           row.hidden = "$bgAlerts != 'Urgent Low'"
                       }
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
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowBG.value = Float(value)
        }
        <<< StepperRow("alertUrgentLowPredictiveMinutes") { row in
            row.title = "Predictive (Minutes)"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 0
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertUrgentLowPredictiveMinutes.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowPredictiveMinutes.value = Int(value)
        }
        <<< StepperRow("alertUrgentLowSnooze") { row in
            row.title = "Default Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 15
            row.value = Double(UserDefaultsRepository.alertUrgentLowSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentLowSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertUrgentLowSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertUrgentLowSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLowSound.value = value //changed
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            
            <<< PickerInputRow<String>("alertUrgentLowPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertUrgentLowAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLowAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertUrgentLowDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertUrgentLowNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertUrgentLowRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertUrgentLowRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLowRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertUrgentLowDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertUrgentLowNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertUrgentLowAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertUrgentLowAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentLowAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentLowAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertUrgentLowAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertUrgentLowSnoozedTime") { row in
            row.title = "Snoozed Until"
            
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertUrgentLowSnoozedTime == nil"
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
            +++ Section(header: "Low Alert", footer: "Alerts when BG drops below value. Persitent for minutes will allow the alert to be ignored within the Delta value to prevent alerts that Loop self-corrected the drop. Predictive minutes looks forward to Loop's prediction and will trigger an alert if a low is predicted within that time frame. Predictive uses the minimum persistence Delta value for the trigger.") { row in
                row.hidden = "$bgAlerts != 'Low'"
            }
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
            row.cell.stepper.maximumValue = 150
            row.value = Double(UserDefaultsRepository.alertLowBG.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowBG.value = Float(value)
        }
        <<< StepperRow("alertLowPersistent") { row in
            row.title = "Persistent For (Minutes)"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 0
            row.cell.stepper.maximumValue = 240
            row.value = Double(UserDefaultsRepository.alertLowPersistent.value)
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return "\(Int(value))"
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowPersistent.value = Int(value)
        }
            <<< StepperRow("alertLowPersistenceMax") { row in
                row.title = "Ignore Persistence (-Delta)"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 0
                row.cell.stepper.maximumValue = 20
                row.value = Double(UserDefaultsRepository.alertLowPersistenceMax.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowPersistenceMax.value = Float(value)
            }
        
            
        <<< StepperRow("alertLowSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 30
            row.value = Double(UserDefaultsRepository.alertLowSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertLowSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertLowSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertLowSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertLowAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertLowDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertLowNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertLowRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertLowRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertLowDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertLowNightTime.value = alertTimes.nightTime
            }
            
            <<< PickerInputRow<String>("alertLowAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertLowAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertLowAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertLowAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertLowAutosnoozeNight.value = alertTimes.nightTime
            }
           
        <<< DateTimeInlineRow("alertLowSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertLowSnoozedTime == nil"
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
        +++ Section(header: "High Alert", footer: "Alerts when BG rises above value. If Persistence is set greater than 0, it will not alert until BG has been high for that many minutes.") { row in
                       row.hidden = "$bgAlerts != 'High'"
                   }
            
        <<< SwitchRow("alertHighActive"){ row in
            row.title = "Active"
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
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighBG.value = Float(value)
        }
        <<< StepperRow("alertHighPersistent") { row in
            row.title = "Persistent For"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 0
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertHighPersistent.value)
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
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertHighSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertHighSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertHighSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertHighPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertHighAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertHighDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertHighNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertHighRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertHighRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertHighDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertHighNightTime.value = alertTimes.nightTime
            }
            
            <<< PickerInputRow<String>("alertHightAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertHighAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertHighAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertHighAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertHighAutosnoozeNight.value = alertTimes.nightTime
            }
            
        <<< DateTimeInlineRow("alertHighSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertHighSnoozedTime == nil"
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
            +++ Section(header: "Urgent High Alert", footer: "Alerts when BG rises above value.") { row in
                           row.hidden = "$bgAlerts != 'Urgent High'"
                       }
        <<< SwitchRow("alertUrgentHighActive"){ row in
                row.title = "Active"
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
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentHighBG.value = Float(value)
        }
        <<< StepperRow("alertUrgentHighSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 10
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertUrgentHighSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertUrgentHighSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertUrgentHighSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertUrgentHighSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentHighSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertUrgentHighPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertUrgentHighAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentHighAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertUrgentHighDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertUrgentHighNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertUrgentHighRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertUrgentHighRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentHighRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertUrgentHighDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertUrgentHighNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertUrgentHighAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertUrgentHighAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertUrgentHighAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentHighAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertUrgentHighAutosnoozeNight.value = alertTimes.nightTime
            }
            
        <<< DateTimeInlineRow("alertUrgentHighSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertUrgentHighSnoozedTime == nil"
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
        +++ Section(header: "Fast Drop Alert", footer: "Alert when BG is dropping fast over consecutive readings. Optional: only alert when dropping below a specific BG") { row in
                                  row.hidden = "$bgExtraAlerts != 'Fast Drop'"
                              }
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
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropDelta.value = Float(value)
        }
        <<< StepperRow("alertFastDropReadings") { row in
            row.title = "# Readings"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 2
            row.cell.stepper.maximumValue = 4
            row.value = Double(UserDefaultsRepository.alertFastDropReadings.value)
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
        row.value = UserDefaultsRepository.alertFastDropUseLimit.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropUseLimit.value = value
        }
    
        <<< StepperRow("alertFastDropBelowBG") { row in
            row.title = "Dropping Below BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 40
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertFastDropBelowBG.value)
            row.hidden = "$alertFastDropUseLimit == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropBelowBG.value = Float(value)
        }
        <<< StepperRow("alertFastDropSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertFastDropSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastDropSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertFastDropSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertFastDropSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastDropSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertFastDropPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertFastDropAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastDropAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertFastDropDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertFastDropNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertFastDropRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertFastDropRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastDropRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertFastDropDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertFastDropNightTime.value = alertTimes.nightTime
            }
            
            <<< PickerInputRow<String>("alertFastDropAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertFastDropAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastDropAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastDropAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertFastDropAutosnoozeNight.value = alertTimes.nightTime
            }
            
        <<< DateTimeInlineRow("alertFastDropSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertFastDropSnoozedTime == nil"
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
        +++ Section(header: "Fast Rise Alert", footer: "Alert when BG is rising fast over consecutive readings. Optional: only alert when rising above a specific BG") { row in
                                         row.hidden = "$bgExtraAlerts != 'Fast Rise'"
                                     }
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
            row.displayValueFor = { value in
                guard let value = value else { return nil }
                return bgUnits.toDisplayUnits(String(value))
            }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseDelta.value = Float(value)
        }
        <<< StepperRow("alertFastRiseReadings") { row in
            row.title = "# Readings"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 2
            row.cell.stepper.maximumValue = 4
            row.value = Double(UserDefaultsRepository.alertFastRiseReadings.value)
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
        row.value = UserDefaultsRepository.alertFastRiseUseLimit.value
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseUseLimit.value = value
        }
    
        <<< StepperRow("alertFastRiseAboveBG") { row in
            row.title = "Rising Above BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 40
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertFastRiseAboveBG.value)
            row.hidden = "$alertFastRiseUseLimit == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseAboveBG.value = Float(value)
        }
        <<< StepperRow("alertFastRiseSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertFastRiseSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertFastRiseSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertFastRiseSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertFastRiseSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastRiseSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertFastRisePlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertFastRiseAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastRiseAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertFastRiseDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertFastRiseNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertFastRiseRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertFastRiseRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastRiseRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertFastRiseDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertFastRiseNightTime.value = alertTimes.nightTime
            }
            
            <<< PickerInputRow<String>("alertFastRiseAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertFastRiseAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertFastRiseAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastRiseAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertFastRiseAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertFastRiseSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertFastRiseSnoozedTime == nil"
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
            +++ Section(header: "No Readings", footer: "Alert when there have been no BG readings for X minutes") { row in
                                             row.hidden = "$bgExtraAlerts != 'No Readings'"
                                         }
        
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
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReadingSnooze.value = Int(value)
            }
            <<< PickerInputRow<String>("alertMissedReadingSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertMissedReadingSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReadingSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertMissedReadingPlaySound") { row in
                row.title = "PlaySound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertMissedReadingAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReadingAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedReadingDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertMissedReadingNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertMissedReadingRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertMissedReadingRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReadingRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedReadingDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertMissedReadingNightTime.value = alertTimes.nightTime
            }
            
            <<< PickerInputRow<String>("alertMissedReadingAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertMissedReadingAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedReadingAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertMissedReadingAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertMissedReadingAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertMissedReadingSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertMissedReadingSnoozedTime == nil"
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
            +++ Section(header: "Not Looping", footer: "Alert when Loop has not completed a successful Loop for X minutes") { row in
                    row.hidden = "$otherAlerts != 'Not Looping'"
                }
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
            row.hidden = "$alertNotLoopingUseLimits == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingLowerLimit.value = Float(value)
        }
        <<< StepperRow("alertNotLoopingUpperLimit") { row in
            row.title = "Above BG"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 100
            row.cell.stepper.maximumValue = 300
            row.value = Double(UserDefaultsRepository.alertNotLoopingUpperLimit.value)
            row.hidden = "$alertNotLoopingUseLimits == false"
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingUpperLimit.value = Float(value)
        }
        <<< StepperRow("alertNotLoopingSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 10
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertNotLoopingSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertNotLoopingSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertNotLoopingSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertNotLoopingSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertNotLoopingPlaySound") { row in
                row.title = "PlaySound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertNotLoopingAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertNotLoopingDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertNotLoopingNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertNotLoopingRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertNotLoopingRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertNotLoopingDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertNotLoopingNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertNotLoopingAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertNotLoopingAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertNotLoopingAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertNotLoopingAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertNotLoopingAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertNotLoopingSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertNotLoopingSnoozedTime == nil"
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
            +++ Section(header: "Missed Bolus", footer: "Alert after X minutes when carbs are entered with no Bolus. Options to Ignore low treatment carbs under a certain BG, ignore small boluses, and consider boluses within a certain amount of time before the carbs as a prebolus.") { row in
                               row.hidden = "$otherAlerts != 'Missed Bolus'"
                           }
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
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolus.value = Int(value)
        }
            <<< StepperRow("alertMissedBolusPrebolus") { row in
                row.title = "Prebolus Max Time"
                row.cell.stepper.stepValue = 5
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 45
                row.value = Double(UserDefaultsRepository.alertMissedBolusPrebolus.value)
                row.displayValueFor = { value in
                        guard let value = value else { return nil }
                        return "\(Int(value))"
                    }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusPrebolus.value = Int(value)
            }
            <<< StepperRow("alertMissedBolusIgnoreBolus") { row in
                row.title = "Ignore Bolus <="
                row.cell.stepper.stepValue = 0.05
                row.cell.stepper.minimumValue = 0.05
                row.cell.stepper.maximumValue = 2
                row.value = Double(UserDefaultsRepository.alertMissedBolusIgnoreBolus.value)
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusIgnoreBolus.value = value
            }
    
        
        <<< StepperRow("alertMissedBolusLowGrams") { row in
            row.title = "Ignore Under Grams"
            row.tag = "missedBolusLowGrams"
            row.cell.stepper.stepValue = 1
            row.cell.stepper.minimumValue = 0
            row.cell.stepper.maximumValue = 15
            row.value = Double(UserDefaultsRepository.alertMissedBolusLowGrams.value)
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
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return bgUnits.toDisplayUnits(String(value))
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusLowGramsBG.value = Float(value)
        }
        
        <<< StepperRow("alertMissedBolusSnooze") { row in
            row.title = "Snooze"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 60
            row.value = Double(UserDefaultsRepository.alertMissedBolusSnooze.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertMissedBolusSnooze.value = Int(value)
        }
            <<< PickerInputRow<String>("alertMissedBolusSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertMissedBolusSound.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertMissedBolusPlaySound") { row in
                row.title = "PlaySound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertMissedBolusAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedBolusDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertMissedBolusNightTimeAudible.value = alertVol.nightTime
            }
            //<<< SwitchRow("alertMissedBolusQuiet"){ row in
            //row.title = "Mute at night"
            //row.value = UserDefaultsRepository.alertMissedBolusQuiet.value
            //}.onChange { [weak self] row in
            //        guard let value = row.value else { return }
            //        UserDefaultsRepository.alertMissedBolusQuiet.value = value
            //}
            <<< PickerInputRow<String>("alertMissedBolusRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertMissedBolusRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedBolusDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertMissedBolusNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertMissedBolusAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertMissedBolusAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertMissedBolusAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertMissedBolusAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertMissedBolusAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertMissedBolusSnoozedTime") { row in
            row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
            row.hidden = "$alertMissedBolusSnoozedTime == nil"
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
            +++ Section(header: "Sensor Change Reminder", footer: "Alert for 10 Day Sensor Change. Values are in Hours.") { row in
                row.hidden = "$otherAlerts != 'SAGE'"
            }
            
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
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertSAGESnooze.value = Int(value)
            }
            
            <<< PickerInputRow<String>("alertSAGESound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertSAGESound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertSAGESound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            //<<< SwitchRow("alertSAGEQuiet"){ row in
            //row.title = "Mute at night"
            //row.value = UserDefaultsRepository.alertSAGEQuiet.value
            //}.onChange { [weak self] row in
            //        guard let value = row.value else { return }
            //        UserDefaultsRepository.alertSAGEQuiet.value = value
            //}
            <<< PickerInputRow<String>("alertSAGEPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertSAGEAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGEAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertSAGEDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertSAGENightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertSAGERepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertSAGERepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGERepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertSAGEDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertSAGENightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertSAGEAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertSAGEAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertSAGEAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertSAGEAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertSAGEAutosnoozeNight.value = alertTimes.nightTime
            }
            <<< DateTimeInlineRow("alertSAGESnoozedTime") { row in
                row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
                row.hidden = "$alertSAGESnoozedTime == nil"
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
            +++ Section(header: "Pump/Canula Change Reminder", footer: "Alert for Canula Change. Values are in Hours.") { row in
                row.hidden = "$otherAlerts != 'CAGE'"
            }
            <<< SwitchRow("alertCAGEActive"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertCAGEActive.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCAGEActive.value = value
            }
            
            <<< StepperRow("alertCAGE") { row in
                row.title = "Time"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertCAGE.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCAGE.value = Int(value)
            }
            <<< StepperRow("alertCAGESnooze") { row in
                row.title = "Snooze"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertCAGESnooze.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCAGESnooze.value = Int(value)
            }
            <<< PickerInputRow<String>("alertCAGESound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertCAGESound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCAGESound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
            }
            <<< PickerInputRow<String>("alertCAGEPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertCAGEAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGEAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCAGEDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertCAGENightTimeAudible.value = alertVol.nightTime
            }
            //<<< SwitchRow("alertCAGEQuiet"){ row in
            //row.title = "Mute at night"
            //row.value = UserDefaultsRepository.alertCAGEQuiet.value
            //}.onChange { [weak self] row in
            //        guard let value = row.value else { return }
            //        UserDefaultsRepository.alertCAGEQuiet.value = value
            //}
            <<< PickerInputRow<String>("alertCAGERepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertCAGERepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGERepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCAGEDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertCAGENightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertCAGEAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertCAGEAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCAGEAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertCAGEAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertCAGEAutosnoozeNight.value = alertTimes.nightTime
            }
            <<< DateTimeInlineRow("alertCAGESnoozedTime") { row in
                row.title = "Snoozed Until"
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
                    cell.datePicker.preferredDatePickerStyle = .wheels
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
                row.hidden = "$alertCAGESnoozedTime == nil"
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
    
    func buildOverrideStart(){
        form
            +++ Section(header: "Override Started Alert", footer: "Alert will trigger without repeat once when override is activated. There is no need to snooze this alert") { row in
                row.hidden = "$otherAlerts2 != 'Override Start'"
            }
            <<< SwitchRow("alertOverrideStart"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertOverrideStart.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideStart.value = value
            }
            
            <<< PickerInputRow<String>("alertOverrideStartSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertOverrideStartSound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideStartSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
        }
            <<< PickerInputRow<String>("alertOverrideStartPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertOverrideStartAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertOverrideStartAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertOverrideStartDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertOverrideStartNightTimeAudible.value = alertVol.nightTime
            }
            //<<< SwitchRow("alertOverrideStartQuiet"){ row in
            //row.title = "Mute at night"
            //row.value = UserDefaultsRepository.alertOverrideStartQuiet.value
            //}.onChange { [weak self] row in
            //        guard let value = row.value else { return }
            //        UserDefaultsRepository.alertOverrideStartQuiet.value = value
            //}
            <<< PickerInputRow<String>("alertOverrideStartRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertOverrideStartRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertOverrideStartRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertOverrideStartDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertOverrideStartNightTime.value = alertTimes.nightTime

            }
            <<< PickerInputRow<String>("alertOverrideStartAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertOverrideStartAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertOverrideStartAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertOverrideStartAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertOverrideStartAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertOverrideStartSnoozedTime") { row in
                row.title = "Snoozed Until"
                if (UserDefaultsRepository.alertOverrideStartSnoozedTime.value != nil) {
                    row.value = UserDefaultsRepository.alertOverrideStartSnoozedTime.value
                }
                row.minuteInterval = 5
                row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideStartSnoozedTime.value = value
                UserDefaultsRepository.alertOverrideStartIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertOverrideStartIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                    cell.datePicker.preferredDatePickerStyle = .wheels
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
            }
            <<< SwitchRow("alertOverrideStartIsSnoozed"){ row in
                row.title = "Is Snoozed"
                row.value = UserDefaultsRepository.alertOverrideStartIsSnoozed.value
                row.hidden = "$alertOverrideStartSnoozedTime == nil"
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideStartIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertOverrideStartSnoozedTime.setNil(key: "alertOverrideStartSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertOverrideStartSnoozedTime") as! DateTimeInlineRow
                    otherRow.value = nil
                    otherRow.reload()
                }
        }
        
    }
    
    func buildOverrideEnd(){
        form
            +++ Section(header: "Override Ended Alert", footer: "Alert will trigger without repeat once when an override is turned off. There is no need to snooze this alert") { row in
                row.hidden = "$otherAlerts2 != 'Override End'"
            }
            <<< SwitchRow("alertOverrideEnd"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertOverrideEnd.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideEnd.value = value
            }
            
            <<< PickerInputRow<String>("alertOverrideEndSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertOverrideEndSound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideEndSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
        }
            <<< PickerInputRow<String>("alertOverrideEndPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertOverrideEndAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertOverrideEndAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertOverrideEndDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertOverrideEndNightTimeAudible.value = alertVol.nightTime
            }
            //<<< SwitchRow("alertOverrideEndQuiet"){ row in
            //row.title = "Mute at night"
            //row.value = UserDefaultsRepository.alertOverrideEndQuiet.value
            //}.onChange { [weak self] row in
            //        guard let value = row.value else { return }
            //        UserDefaultsRepository.alertOverrideEndQuiet.value = value
            //}
            <<< PickerInputRow<String>("alertOverrideEndRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertOverrideEndRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertOverrideEndRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertOverrideEndDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertOverrideEndNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertOverrideEndAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertOverrideEndAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertOverrideEndAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertOverrideEndAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertOverrideEndAutosnoozeNight.value = alertTimes.nightTime
            }
        <<< DateTimeInlineRow("alertOverrideEndSnoozedTime") { row in
                row.title = "Snoozed Until"
                if (UserDefaultsRepository.alertOverrideEndSnoozedTime.value != nil) {
                    row.value = UserDefaultsRepository.alertOverrideEndSnoozedTime.value
                }
                row.minuteInterval = 5
                row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideEndSnoozedTime.value = value
                UserDefaultsRepository.alertOverrideEndIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertOverrideEndIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                    cell.datePicker.preferredDatePickerStyle = .wheels
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
            }
            <<< SwitchRow("alertOverrideEndIsSnoozed"){ row in
                row.title = "Is Snoozed"
                row.value = UserDefaultsRepository.alertOverrideEndIsSnoozed.value
                row.hidden = "$alertOverrideEndSnoozedTime == nil"
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertOverrideEndIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertOverrideEndSnoozedTime.setNil(key: "alertOverrideEndSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertOverrideEndSnoozedTime") as! DateTimeInlineRow
                    otherRow.value = nil
                    otherRow.reload()
                }
        }
        
    }
    
    func buildPump() {
        form
            +++ Section(header: "Pump", footer: "Alert will trigger when pump reservoir is below value") { row in
                row.hidden = "$otherAlerts2 != 'Pump'"
            }
            <<< SwitchRow("alertPump"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertPump.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertPump.value = value
            }
            
            <<< StepperRow("alertPumpAt") { row in
                row.title = "Units Remaining"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 49
                row.value = Double(UserDefaultsRepository.alertPumpAt.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertPumpAt.value = Int(value)
            }
            
            <<< StepperRow("alertPumpSnoozeHours") { row in
                row.title = "Snooze Hours"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 24
                row.value = Double(UserDefaultsRepository.alertPumpSnoozeHours.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertPumpSnoozeHours.value = Int(value)
            }
            <<< PickerInputRow<String>("alertPumpSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertPumpSound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertPumpSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
        }
            <<< PickerInputRow<String>("alertPumpPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertPumpAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertPumpAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertPumpDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertPumpNightTimeAudible.value = alertVol.nightTime
            }
            //<<< SwitchRow("alertPumpQuiet"){ row in
            //row.title = "Mute at night"
            //row.value = UserDefaultsRepository.alertPumpQuiet.value
            //}.onChange { [weak self] row in
            //        guard let value = row.value else { return }
            //        UserDefaultsRepository.alertPumpQuiet.value = value
            //}
            <<< PickerInputRow<String>("alertPumpRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertPumpRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertPumpRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertPumpDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertPumpNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertPumpAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertPumpAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertPumpAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertPumpAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertPumpAutosnoozeNight.value = alertTimes.nightTime
            }
            <<< DateTimeInlineRow("alertPumpSnoozedTime") { row in
                row.title = "Snoozed Until"
                if (UserDefaultsRepository.alertPumpSnoozedTime.value != nil) {
                    row.value = UserDefaultsRepository.alertPumpSnoozedTime.value
                }
                row.minuteInterval = 5
                row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertPumpSnoozedTime.value = value
                UserDefaultsRepository.alertPumpIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertPumpIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                    cell.datePicker.preferredDatePickerStyle = .wheels
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
            }
            <<< SwitchRow("alertPumpIsSnoozed"){ row in
                row.title = "Is Snoozed"
                row.value = UserDefaultsRepository.alertPumpIsSnoozed.value
                row.hidden = "$alertPumpSnoozedTime == nil"
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertPumpIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertPumpSnoozedTime.setNil(key: "alertPumpSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertPumpSnoozedTime") as! DateTimeInlineRow
                    otherRow.value = nil
                    otherRow.reload()
                }
        }
    }
    
    func buildIOB() {
        form
            +++ Section(header: "IOB", footer: "Alert will trigger when IOB is above value.The Total Bolus Within option with allow the alert to use the reported IOB or sum of the Boluses") { row in
                row.hidden = "$otherAlerts3 != 'IOB'"
            }
            <<< SwitchRow("alertIOB"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertIOB.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOB.value = value
            }
            
            <<< StepperRow("alertIOBAt") { row in
                row.title = "IOB >="
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 50
                row.value = Double(UserDefaultsRepository.alertIOBAt.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOBAt.value = Int(value)
            }
        <<< StepperRow("alertIOBBolusesWithin") { row in
            row.title = "Or Total Boluses (Min)"
            row.cell.stepper.stepValue = 5
            row.cell.stepper.minimumValue = 5
            row.cell.stepper.maximumValue = 120
            row.value = Double(UserDefaultsRepository.alertIOBBolusesWithin.value)
            row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOBBolusesWithin.value = Int(value)
        }
            
            <<< StepperRow("alertIOBSnoozeHours") { row in
                row.title = "Snooze Hours"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 6
                row.value = Double(UserDefaultsRepository.alertIOBSnoozeHours.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOBSnoozeHours.value = Int(value)
            }
            <<< PickerInputRow<String>("alertIOBSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertIOBSound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOBSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
        }
            <<< PickerInputRow<String>("alertIOBPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertIOBAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertIOBAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertIOBDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertIOBNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertIOBRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertIOBRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertIOBRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertIOBDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertIOBNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertIOBAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertIOBAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertIOBAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertIOBAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertIOBAutosnoozeNight.value = alertTimes.nightTime
            }
            <<< DateTimeInlineRow("alertIOBSnoozedTime") { row in
                row.title = "Snoozed Until"
                if (UserDefaultsRepository.alertIOBSnoozedTime.value != nil) {
                    row.value = UserDefaultsRepository.alertIOBSnoozedTime.value
                }
                row.minuteInterval = 5
                row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOBSnoozedTime.value = value
                UserDefaultsRepository.alertIOBIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertIOBIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                    cell.datePicker.preferredDatePickerStyle = .wheels
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
            }
            <<< SwitchRow("alertIOBIsSnoozed"){ row in
                row.title = "Is Snoozed"
                row.value = UserDefaultsRepository.alertIOBIsSnoozed.value
                row.hidden = "$alertIOBSnoozedTime == nil"
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertIOBIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertIOBSnoozedTime.setNil(key: "alertIOBSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertIOBSnoozedTime") as! DateTimeInlineRow
                    otherRow.value = nil
                    otherRow.reload()
                }
        }
    }
    
    func buildCOB() {
        form
            +++ Section(header: "COB", footer: "Alert will trigger when COB is above value") { row in
                row.hidden = "$otherAlerts3 != 'COB'"
            }
            <<< SwitchRow("alertCOB"){ row in
                row.title = "Active"
                row.value = UserDefaultsRepository.alertCOB.value
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCOB.value = value
            }
            
            <<< StepperRow("alertCOBAt") { row in
                row.title = "COB >="
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 200
                row.value = Double(UserDefaultsRepository.alertCOBAt.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCOBAt.value = Int(value)
            }
        
            
            <<< StepperRow("alertCOBSnoozeHours") { row in
                row.title = "Snooze Hours"
                row.cell.stepper.stepValue = 1
                row.cell.stepper.minimumValue = 1
                row.cell.stepper.maximumValue = 6
                row.value = Double(UserDefaultsRepository.alertCOBSnoozeHours.value)
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(Int(value))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCOBSnoozeHours.value = Int(value)
            }
            <<< PickerInputRow<String>("alertCOBSound") { row in
                row.title = "Sound"
                row.options = soundFiles
                row.value = UserDefaultsRepository.alertCOBSound.value
                row.displayValueFor = { value in
                    guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCOBSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()
        }
            <<< PickerInputRow<String>("alertCOBPlaySound") { row in
                row.title = "Play Sound"
                row.options = alertPlaySoundOptions
                row.value = UserDefaultsRepository.alertCOBAudible.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCOBAudible.value = value
                    let alertVol = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCOBDayTimeAudible.value = alertVol.dayTime
                    UserDefaultsRepository.alertCOBNightTimeAudible.value = alertVol.nightTime
            }
            <<< PickerInputRow<String>("alertCOBRepeat") { row in
                row.title = "Repeat Sound"
                row.options = alertRepeatOptions
                row.value = UserDefaultsRepository.alertCOBRepeat.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCOBRepeat.value = value
                    let alertTimes = self!.timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCOBDayTime.value = alertTimes.dayTime
                    UserDefaultsRepository.alertCOBNightTime.value = alertTimes.nightTime
            }
            <<< PickerInputRow<String>("alertCOBAutoSnooze") { row in
                row.title = "Pre-Snooze"
                row.options = alertAutosnoozeOptions
                row.value = UserDefaultsRepository.alertCOBAutosnooze.value
                row.displayValueFor = { value in
                guard let value = value else { return nil }
                    return "\(String(value.replacingOccurrences(of: "_", with: " ")))"
                }
            }.onChange { [weak self] row in
                    guard let value = row.value else { return }
                    UserDefaultsRepository.alertCOBAutosnooze.value = value
                let alertTimes = self!.timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertCOBAutosnoozeDay.value = alertTimes.dayTime
                UserDefaultsRepository.alertCOBAutosnoozeNight.value = alertTimes.nightTime
            }
            <<< DateTimeInlineRow("alertCOBSnoozedTime") { row in
                row.title = "Snoozed Until"
                if (UserDefaultsRepository.alertCOBSnoozedTime.value != nil) {
                    row.value = UserDefaultsRepository.alertCOBSnoozedTime.value
                }
                row.minuteInterval = 5
                row.noValueDisplayText = "Not Snoozed"
            }
            .onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCOBSnoozedTime.value = value
                UserDefaultsRepository.alertCOBIsSnoozed.value = true
                let otherRow = self?.form.rowBy(tag: "alertCOBIsSnoozed") as! SwitchRow
                otherRow.value = true
                otherRow.reload()
            }
            .onExpandInlineRow { [weak self] cell, row, inlineRow in
                inlineRow.cellUpdate() { cell, row in
                    cell.datePicker.datePickerMode = .dateAndTime
                    cell.datePicker.preferredDatePickerStyle = .wheels
                }
                let color = cell.detailTextLabel?.textColor
                row.onCollapseInlineRow { cell, _, _ in
                    cell.detailTextLabel?.textColor = color
                }
                cell.detailTextLabel?.textColor = cell.tintColor
            }
            <<< SwitchRow("alertCOBIsSnoozed"){ row in
                row.title = "Is Snoozed"
                row.value = UserDefaultsRepository.alertCOBIsSnoozed.value
                row.hidden = "$alertCOBSnoozedTime == nil"
            }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.alertCOBIsSnoozed.value = value
                if !value {
                    UserDefaultsRepository.alertCOBSnoozedTime.setNil(key: "alertCOBSnoozedTime")
                    let otherRow = self?.form.rowBy(tag: "alertCOBSnoozedTime") as! DateTimeInlineRow
                    otherRow.value = nil
                    otherRow.reload()
                }
        }
    }

    func buildAlarmSettings() {
           form
            +++ Section(header: "Alarm Sound Settings", footer: "")
           
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
            
             +++ Section(header: "Night Time Settings", footer: "Night time hours are used to differ how alerts are managed during the day and at night.  For instance, automatically snooze, at night time, non-critical alerts that you do not wish to be awakened for such as a sensor change pre-alert.")  { row in
                row.tag = "quietHourSection"
                        }
            <<< TimeInlineRow("quietHourStart") { row in
                row.title = "Night Time Starts Today"
                row.value = UserDefaultsRepository.quietHourStart.value
                
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.quietHourStart.value = value
        }
        <<< TimeInlineRow("quietHourEnd") { row in
                row.title = "Night Time Ends Tomorrow"
                row.value = UserDefaultsRepository.quietHourEnd.value
                
        }.onChange { [weak self] row in
                guard let value = row.value else { return }
                UserDefaultsRepository.quietHourEnd.value = value
        }
       }

}


