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
    
    // Main Download Timer
    func startTimer(time: TimeInterval) {
        timer = Timer.scheduledTimer(timeInterval: time,
                                     target: self,
                                     selector: #selector(MainViewController.timerDidEnd(_:)),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    // Check for new data when timer ends
    @objc func timerDidEnd(_ timer:Timer) {
        nightscoutLoader()
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
    
    // NS Loader Timer
    func startViewTimer(time: TimeInterval) {
        viewTimer = Timer.scheduledTimer(timeInterval: time,
                                         target: self,
                                         selector: #selector(MainViewController.viewTimerDidEnd(_:)),
                                         userInfo: nil,
                                         repeats: false)
        
    }
    
    // This delays a few things to hopefully all all data to arrive.
    @objc func viewTimerDidEnd(_ timer:Timer) {
        if bgData.count > 0 {
            self.checkAlarms(bgs: bgData)
            //self.updateMinAgo()
            // self.updateBadge(val: bgData[bgData.count - 1].sgv)
            //self.viewUpdateNSBG()
            if UserDefaultsRepository.writeCalendarEvent.value {
                self.writeCalendar()
            }
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
