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
        if !bgTimer.isValid { startBGTimer(time: 2) }
        if !profileTimer.isValid { startProfileTimer(time: 3) }
        if !deviceStatusTimer.isValid { startDeviceStatusTimer(time: 4) }
        if !treatmentsTimer.isValid { startTreatmentsTimer(time: 5) }
        if !cageSageTimer.isValid { startCageSageTimer(time: 6) }
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
            
            if let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController {
                snoozer.MinAgoLabel.text = formattedDuration ?? ""
                snoozer.MinAgoLabel.text! += " min ago"
            } else { return }
            
        } else {
            MinAgoText.text = ""
            latestMinAgoString = ""
            
            if let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController {
                snoozer.MinAgoLabel.text = ""
            } else { return }
            
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
        createVerticalLines()
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
        if UserDefaultsRepository.url.value == "" || !UserDefaultsRepository.loopUser.value {
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
        if UserDefaultsRepository.url.value == "" || !UserDefaultsRepository.loopUser.value {
            startTreatmentsTimer(time: 60)
            return
        }
        
        if UserDefaultsRepository.url.value != "" && UserDefaultsRepository.downloadTreatments.value {
                WebLoadNSTreatments()
            }
            startTreatmentsTimer()
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
        if UserDefaultsRepository.url.value == "" || !UserDefaultsRepository.loopUser.value {
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
        if UserDefaultsRepository.url.value == "" || !UserDefaultsRepository.loopUser.value {
            startCageSageTimer(time: 60)
            return
        }
        
        if UserDefaultsRepository.url.value != "" {
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
        if overrideGraphData.count > 0 {
            self.checkOverrideAlarms()
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
