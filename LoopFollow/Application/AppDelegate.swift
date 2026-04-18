// LoopFollow
// AppDelegate.swift

import AVFoundation
import CoreData
import EventKit
import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let notificationCenter = UNUserNotificationCenter.current()

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LogManager.shared.log(category: .general, message: "App started")
        LogManager.shared.cleanupOldLogs()

        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        notificationCenter.requestAuthorization(options: options) {
            didAllow, _ in
            if !didAllow {
                LogManager.shared.log(category: .general, message: "User has declined notifications")
            }
        }

        let store = EKEventStore()
        store.requestCalendarAccess { granted, error in
            if !granted {
                LogManager.shared.log(category: .calendar, message: "Failed to get calendar access: \(String(describing: error))")
                return
            }
        }

        let action = UNNotificationAction(identifier: "OPEN_APP_ACTION", title: "Open App", options: .foreground)
        let category = UNNotificationCategory(identifier: BackgroundAlertIdentifier.categoryIdentifier, actions: [action], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])

        UNUserNotificationCenter.current().delegate = self

        _ = BLEManager.shared
        // Ensure VolumeButtonHandler is initialized so it can receive alarm notifications
        _ = VolumeButtonHandler.shared

        // Register for remote notifications
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }

        BackgroundRefreshManager.shared.register()

        // Detect Before-First-Unlock launch. If protected data is unavailable here,
        // StorageValues were cached from encrypted UserDefaults and need a reload
        // on the first foreground after the user unlocks.
        let bfu = !UIApplication.shared.isProtectedDataAvailable
        Storage.shared.needsBFUReload = bfu
        LogManager.shared.log(category: .general, message: "BFU check: isProtectedDataAvailable=\(!bfu), needsBFUReload=\(bfu)")

        return true
    }

    func applicationWillTerminate(_: UIApplication) {
        #if !targetEnvironment(macCatalyst)
            LiveActivityManager.shared.endOnTerminate()
        #endif
    }

    // MARK: - Remote Notifications

    /// Called when successfully registered for remote notifications
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Observable.shared.loopFollowDeviceToken.value = tokenString

        LogManager.shared.log(category: .apns, message: "Successfully registered for remote notifications with token: \(tokenString)")
    }

    /// Called when failed to register for remote notifications
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogManager.shared.log(category: .apns, message: "Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Called when a remote notification is received
    func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        LogManager.shared.log(category: .apns, message: "Received remote notification: \(userInfo)")

        // Check if this is a response notification from Loop or Trio
        if let aps = userInfo["aps"] as? [String: Any] {
            // Handle visible notification (alert, sound, badge)
            if let alert = aps["alert"] as? [String: Any] {
                let title = alert["title"] as? String ?? ""
                let body = alert["body"] as? String ?? ""
                LogManager.shared.log(category: .apns, message: "Notification - Title: \(title), Body: \(body)")
            }

            // Handle silent notification (content-available)
            if let contentAvailable = aps["content-available"] as? Int, contentAvailable == 1 {
                // This is a silent push, nothing implemented but logging for now

                if let commandStatus = userInfo["command_status"] as? String {
                    LogManager.shared.log(category: .apns, message: "Command status: \(commandStatus)")
                }

                if let commandType = userInfo["command_type"] as? String {
                    LogManager.shared.log(category: .apns, message: "Command type: \(commandType)")
                }
            }
        }

        // Call completion handler
        completionHandler(.newData)
    }

    func application(_: UIApplication, willFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIApplication.shared.isIdleTimerDisabled = Storage.shared.screenlockSwitchState.value
        return true
    }

    // MARK: - Quick Actions

    func application(_: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            completionHandler(false)
            return
        }
        let expectedType = bundleIdentifier + ".toggleSpeakBG"
        if shortcutItem.type == expectedType {
            Storage.shared.speakBG.value.toggle()
            let message = Storage.shared.speakBG.value ? "BG Speak is now on" : "BG Speak is now off"
            let utterance = AVSpeechUtterance(string: message)
            AVSpeechSynthesizer().speak(utterance)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentCloudKitContainer(name: "LoopFollow")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "OPEN_APP_ACTION" {
            // Switch to Home tab
            Observable.shared.selectedTabIndex.value = 0
        }

        if response.actionIdentifier == "snooze" {
            AlarmManager.shared.performSnooze()
        }

        completionHandler()
    }

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        let forcePortrait = Storage.shared.forcePortraitMode.value

        if forcePortrait {
            return .portrait
        } else {
            return .all
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        // Log the notification
        let userInfo = notification.request.content.userInfo
        LogManager.shared.log(category: .general, message: "Will present notification: \(userInfo)")

        // Show the notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
