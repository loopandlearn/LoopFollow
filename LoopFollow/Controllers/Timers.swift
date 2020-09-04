//
//  Timers.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 9/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit


extension MainViewController {
    
    func restartAllTimers() {
        if !deviceStatusTimer.isValid { startDeviceStatusTimer(time: 1) }
        if !profileTimer.isValid { startProfileTimer(time: 1) }
        if !bgTimer.isValid { startBGTimer(time: 1) }
        if !treatmentsTimer.isValid { startTreatmentsTimer(time: 1) }
        if !cageSageTimer.isValid { startCageSageTimer(time: 1) }
        if !minAgoTimer.isValid { startMinAgoTimer(time: minAgoTimeInterval) }
        if !calendarTimer.isValid { startCalendarTimer(time: 15) }
        if !alarmTimer.isValid { startAlarmTimer(time: 30) }
    }
    
    
    // min Ago Timer
    func startMinAgoTimer(time: TimeInterval) {
        minAgoTimer = Timer.scheduledTimer(timeInterval: time,
                                           target: self,
                                           selector: #selector(MainViewController.minAgoTimerDidEnd(_:)),
                                           userInfo: nil,
                                           repeats: true)
    }
    
    // Updates Min Ago display
    @objc func minAgoTimerDidEnd(_ timer:Timer) {
        
        // print("min ago timer ended")
        if bgData.count > 0 {
            let bgSeconds = bgData.last!.date
            let now = Date().timeIntervalSince1970
            let secondsAgo = now - bgSeconds
            
            // Update Min Ago Displays
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            
            if secondsAgo < 270 {
                formatter.allowedUnits = [ .minute] // Units to display in the formatted string
            } else {
                formatter.allowedUnits = [ .minute, .second] // Units to display in the formatted string
            }
            
            
            //formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
            let formattedDuration = formatter.string(from: secondsAgo)
            
            MinAgoText.text = formattedDuration ?? ""
            MinAgoText.text! += " min ago"
            latestMinAgoString = formattedDuration ?? ""
            latestMinAgoString += " min ago"
            
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.MinAgoLabel.text = formattedDuration ?? ""
            snoozer.MinAgoLabel.text! += " min ago"
        } else {
            MinAgoText.text = ""
            latestMinAgoString = ""
            
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.MinAgoLabel.text = ""
        }
        
    }
    
    // Runs a 60 second timer when an alarm is snoozed
    // Prevents the alarm from triggering again while saving the snooze time to settings
    // End function needs nothing done
    func startGraphNowTimer(time: TimeInterval = 60) {
        
        graphNowTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.graphNowTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: true)
    }
    
    @objc func graphNowTimerDidEnd(_ timer:Timer) {
        createNowLine()
    }
    
    // Runs a 60 second timer when an alarm is snoozed
    // Prevents the alarm from triggering again while saving the snooze time to settings
    // End function needs nothing done
    func startCheckAlarmTimer(time: TimeInterval = 60) {
        
        checkAlarmTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.checkAlarmTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func checkAlarmTimerDidEnd(_ timer:Timer) {
    }
    
    // BG Timer
    // Runs to 5:10 after last reading timestamp
    // Failed or no reading re-attempts after 10 second delay
    // Changes to 30 second increments after 7:00
    // Changes to 1 minute increments after 10:00
    // Changes to 5 minute increments after 20:00 stale data
    func startBGTimer(time: TimeInterval =  60 * 5) {
        bgTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.bgTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func bgTimerDidEnd(_ timer:Timer) {
        
        // reset timer to 1 minute if settings aren't entered
        if UserDefaultsRepository.shareUserName.value == "" && UserDefaultsRepository.sharePassword.value == "" && UserDefaultsRepository.url.value == "" {
            startBGTimer(time: 60)
            return
        }
        
        var onlyPullLastRecord = false
        
        // Check if the last reading is less than 10 minutes ago
        // to only pull 1 reading if that's all we need
        if bgData.count > 0 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let lastReadingTime = bgData.last!.date
            let secondsAgo = now - lastReadingTime
            if secondsAgo < 10*60 {
                onlyPullLastRecord = true
            }
        }
        
        if UserDefaultsRepository.shareUserName.value != "" && UserDefaultsRepository.sharePassword.value != "" {
            webLoadDexShare(onlyPullLastRecord: onlyPullLastRecord)
        } else {
            webLoadNSBGData(onlyPullLastRecord: onlyPullLastRecord)
        }
        
    }
    
    // Device Status Timer
    // Runs to 5:10 after last reading timestamp
    // Failed or no update re-attempts after 10 second delay
    // Changes to 30 second increments after 7:00
    // Changes to 1 minute increments after 10:00
    // Changes to 5 minute increments after 20:00 stale data
    func startDeviceStatusTimer(time: TimeInterval =  60 * 5) {
        deviceStatusTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.deviceStatusTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func deviceStatusTimerDidEnd(_ timer:Timer) {
        
        // reset timer to 1 minute if settings aren't entered
        if UserDefaultsRepository.url.value == "" {
            startDeviceStatusTimer(time: 60)
            return
        }
        
        if UserDefaultsRepository.url.value != "" {
            webLoadNSDeviceStatus()
        }
    }
    
    // Treatments Timer
    // Runs on 2 minute intervals
    // Pauses with stale BG data
    func startTreatmentsTimer(time: TimeInterval =  60 * 2) {
        treatmentsTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.treatmentsTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func treatmentsTimerDidEnd(_ timer:Timer) {
        
        // reset timer to 1 minute if settings aren't entered
        if UserDefaultsRepository.url.value == "" {
            startTreatmentsTimer(time: 60)
            return
        }
        
        if !isStaleData() && UserDefaultsRepository.url.value != "" {
            if UserDefaultsRepository.downloadBasal.value {
                WebLoadNSTempBasals()
            }
            if UserDefaultsRepository.downloadBolus.value {
                webLoadNSBoluses()
            }
            if UserDefaultsRepository.downloadCarbs.value {
                webLoadNSCarbs()
            }
            startTreatmentsTimer()
        }
    }
    
    // Profile Timer
    // Runs on 10 minute intervals
    // Pauses with stale BG data
    func startProfileTimer(time: TimeInterval =  60 * 10) {
        profileTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.profileTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func profileTimerDidEnd(_ timer:Timer) {
        
        // reset timer to 1 minute if settings aren't entered
        if UserDefaultsRepository.url.value == "" {
            startProfileTimer(time: 60)
            return
        }
        
        if !isStaleData() && UserDefaultsRepository.url.value != "" {
            webLoadNSProfile()
            startProfileTimer()
        }
    }
    
    // Cage and Sage Timer
    // Runs on 10 minute intervals
    // Pauses with stale BG data
    func startCageSageTimer(time: TimeInterval =  60 * 10) {
        cageSageTimer = Timer.scheduledTimer(timeInterval: time,
                                               target: self,
                                               selector: #selector(MainViewController.cageSageTimerDidEnd(_:)),
                                               userInfo: nil,
                                               repeats: false)
    }
    
    @objc func cageSageTimerDidEnd(_ timer:Timer) {
        
        // reset timer to 1 minute if settings aren't entered
        if UserDefaultsRepository.url.value == "" {
            startCageSageTimer(time: 60)
            return
        }
        
        if !isStaleData() && UserDefaultsRepository.url.value != "" {
            webLoadNSCage()
            webLoadNSSage()
            startCageSageTimer()
        }
    }
    
    // Cancel and reset the playing alarm if it has not been snoozed after 4 min 50 seconds.
    // This allows the next BG reading to either start the timer going or not fire if the situation has been resolved
    func startAlarmPlayingTimer(time: TimeInterval = 290) {
        let alarmPlayingTimer = Timer.scheduledTimer(timeInterval: time,
                                           target: self,
                                           selector: #selector(MainViewController.alarmPlayingTimerDidEnd(_:)),
                                           userInfo: nil,
                                           repeats: false)
    }
    
    @objc func alarmPlayingTimerDidEnd(_ timer:Timer) {
        if AlarmSound.isPlaying {
            stopAlarmAtNextReading()
        }
    }
    
    
    // Alarm Timer
    // Run the alarm checker every 15 seconds
    func startAlarmTimer(time: TimeInterval) {
        alarmTimer = Timer.scheduledTimer(timeInterval: time,
                                         target: self,
                                         selector: #selector(MainViewController.alarmTimerDidEnd(_:)),
                                         userInfo: nil,
                                         repeats: true)
        
    }
    
    @objc func alarmTimerDidEnd(_ timer:Timer) {
        if bgData.count > 0 {
            self.checkAlarms(bgs: bgData)
        }
    }
    
    // Calendar Timer
    // Run the calendar writer every 30 seconds
    func startCalendarTimer(time: TimeInterval) {
        calendarTimer = Timer.scheduledTimer(timeInterval: time,
                                         target: self,
                                         selector: #selector(MainViewController.calendarTimerDidEnd(_:)),
                                         userInfo: nil,
                                         repeats: true)
        
    }
    
    @objc func calendarTimerDidEnd(_ timer:Timer) {
        if UserDefaultsRepository.writeCalendarEvent.value && UserDefaultsRepository.calendarIdentifier.value != "" {
            self.writeCalendar()
        }
    }
    
    
    
    // Timer to allow us to write min ago calendar entries but not update them every 30 seconds
    func startCalTimer(time: TimeInterval) {
        calTimer = Timer.scheduledTimer(timeInterval: time,
                                        target: self,
                                        selector: #selector(MainViewController.calTimerDidEnd(_:)),
                                        userInfo: nil,
                                        repeats: false)
    }
    
    // Nothing should be done when this timer ends because it just blocks the calendar from writing when it's active
    @objc func calTimerDidEnd(_ timer:Timer) {
        
    }
    
}
