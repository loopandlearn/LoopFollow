//
//  BackgroundAlertManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-06-22.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UserNotifications

/// Enum representing different background alert durations.
enum BackgroundAlertDuration: TimeInterval, CaseIterable {
    case sixMinutes = 360 // 6 minutes in seconds
    case twelveMinutes = 720 // 12 minutes in seconds
    case eighteenMinutes = 1080 // 18 minutes in seconds
}

/// Enum representing unique identifiers for each background alert.
enum BackgroundAlertIdentifier: String, CaseIterable {
    case sixMin = "loopfollow.background.alert.6min"
    case twelveMin = "loopfollow.background.alert.12min"
    case eighteenMin = "loopfollow.background.alert.18min"
}

class BackgroundAlertManager {
    static let shared = BackgroundAlertManager()

    private init() {}

    /// Flag indicating whether background alerts are currently scheduled.
    private var isAlertScheduled: Bool = false

    /// Title prefix for all background refresh notifications.
    private let notificationTitlePrefix = "LoopFollow Background Refresh"

    /// Timestamp of the last scheduled background alert.
    private var lastScheduleDate: Date?

    /// Start scheduling background alerts.
    func startBackgroundAlert() {
        isAlertScheduled = true
        // Force execution to bypass throttle when starting
        scheduleBackgroundAlert(force: true)
    }

    /// Stop all scheduled background alerts.
    func stopBackgroundAlert() {
        isAlertScheduled = false
        removeDeliveredNotifications()
        cancelBackgroundAlerts()
    }

    /// (Re)schedule all background alerts based on predefined durations.
    /// - Parameter force: When true, the scheduling is executed regardless of throttle constraints.
    func scheduleBackgroundAlert(force: Bool = false) {
        guard isAlertScheduled, Storage.shared.backgroundRefreshType.value != .none else { return }

        // Throttle execution if not forced: only run once every 10 seconds.
        if !force {
            let now = Date()
            if let lastDate = lastScheduleDate, now.timeIntervalSince(lastDate) < 10 {
                return
            }
            lastScheduleDate = now
        }

        removeDeliveredNotifications()

        let isBluetoothActive = Storage.shared.backgroundRefreshType.value.isBluetooth
        let expectedHeartbeat = BLEManager.shared.expectedHeartbeatInterval()

        // Define alerts
        let alerts: [BackgroundAlert] = [
            BackgroundAlert(
                identifier: BackgroundAlertIdentifier.sixMin.rawValue,
                timeInterval: BackgroundAlertDuration.sixMinutes.rawValue,
                body: isBluetoothActive
                    ? "App inactive for 6 minutes. Verify Bluetooth connectivity."
                    : "App inactive for 6 minutes. Open to resume."
            ),
            BackgroundAlert(
                identifier: BackgroundAlertIdentifier.twelveMin.rawValue,
                timeInterval: BackgroundAlertDuration.twelveMinutes.rawValue,
                body: isBluetoothActive
                    ? "App inactive for 12 minutes. Verify Bluetooth connectivity."
                    : "App inactive for 12 minutes. Open to resume."
            ),
            BackgroundAlert(
                identifier: BackgroundAlertIdentifier.eighteenMin.rawValue,
                timeInterval: BackgroundAlertDuration.eighteenMinutes.rawValue,
                body: isBluetoothActive
                    ? "App inactive for 18 minutes. Verify Bluetooth connectivity."
                    : "App inactive for 18 minutes. Open to resume."
            ),
        ]

        for alert in alerts {
            // Skip if the expected heartbeat interval matches or exceeds 1.2x the alert time interval
            if let heartbeat = expectedHeartbeat, heartbeat * 1.2 >= alert.timeInterval {
                continue
            }

            let content = createNotificationContent(for: notificationTitlePrefix, body: alert.body)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: alert.timeInterval, repeats: false)
            let request = UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    LogManager.shared.log(category: .general, message: "Error scheduling \(alert.timeInterval / 60)-minute background alert: \(error)")
                }
            }
        }
    }

    /// Create notification content with a given title and body.
    /// - Parameters:
    ///   - title: The title of the notification.
    ///   - body: The body text of the notification.
    /// - Returns: Configured `UNMutableNotificationContent` object.
    private func createNotificationContent(for title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical
        content.categoryIdentifier = "loopfollow.background.alert"
        return content
    }

    /// Cancel all scheduled background alerts.
    private func cancelBackgroundAlerts() {
        let identifiers = BackgroundAlertIdentifier.allCases.map { $0.rawValue }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Remove all delivered notifications.
    private func removeDeliveredNotifications() {
        let identifiers = BackgroundAlertIdentifier.allCases.map { $0.rawValue }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

/// Struct representing a single background alert.
struct BackgroundAlert {
    let identifier: String
    let timeInterval: TimeInterval
    let body: String
}
