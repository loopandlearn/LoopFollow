//
//  BackgroundAlertManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-06-22.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UserNotifications

class BackgroundAlertManager {
    static let shared = BackgroundAlertManager()
    
    private init() {}
    
    private var isAlertScheduled: Bool = false
    
    func startBackgroundAlert() {
        isAlertScheduled = true
        scheduleBackgroundAlert()
    }
    
    func stopBackgroundAlert() {
        isAlertScheduled = false
        cancelBackgroundAlert()
    }
    
    func scheduleBackgroundAlert() {
        guard isAlertScheduled, UserDefaultsRepository.backgroundRefresh.value else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "LoopFollow Background Refresh"
        content.body = "The app is not active, open the app to resume."
        content.sound = .defaultCritical
        content.categoryIdentifier = "loopfollow.background.alert"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 360, repeats: false)
        
        let request = UNNotificationRequest(identifier: "loopfollow.background.alert", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling background alert: \(error)")
            }
        }
    }
    
    private func cancelBackgroundAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["loopfollow.background.alert"])
    }
}
