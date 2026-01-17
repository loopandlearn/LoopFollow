// LoopFollow
// AppDelegate.swift

import CoreData
import EventKit
import UIKit
import UserNotifications

@UIApplicationMain
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
        let category = UNNotificationCategory(identifier: "loopfollow.background.alert", actions: [action], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])

        UNUserNotificationCenter.current().delegate = self

        _ = BLEManager.shared
        // Ensure VolumeButtonHandler is initialized so it can receive alarm notifications
        _ = VolumeButtonHandler.shared

        // Register for remote notifications
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return true
    }

    func applicationWillTerminate(_: UIApplication) {}

    // MARK: - Remote Notifications

    // Called when successfully registered for remote notifications
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Observable.shared.loopFollowDeviceToken.value = tokenString

        LogManager.shared.log(category: .general, message: "Successfully registered for remote notifications with token: \(tokenString)")
    }

    // Called when failed to register for remote notifications
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogManager.shared.log(category: .general, message: "Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // Called when a remote notification is received
    func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        LogManager.shared.log(category: .general, message: "Received remote notification: \(userInfo)")

        // Check if this is a response notification from Loop or Trio
        if let aps = userInfo["aps"] as? [String: Any] {
            // Handle visible notification (alert, sound, badge)
            if let alert = aps["alert"] as? [String: Any] {
                let title = alert["title"] as? String ?? ""
                let body = alert["body"] as? String ?? ""
                LogManager.shared.log(category: .general, message: "Notification - Title: \(title), Body: \(body)")

                // Check if this is a command response from Loop
                if let commandStatus = userInfo["command_status"] as? String,
                   let commandType = userInfo["command_type"] as? String
                {
                    LogManager.shared.log(category: .apns, message: "Loop command response - Type: \(commandType), Status: \(commandStatus), Message: \(body)")

                    // Post notification for UI to handle if needed
                    NotificationCenter.default.post(
                        name: NSNotification.Name("LoopCommandResponse"),
                        object: nil,
                        userInfo: [
                            "commandType": commandType,
                            "commandStatus": commandStatus,
                            "message": body,
                            "title": title,
                        ]
                    )
                }
            }

            // Handle silent notification (content-available)
            if let contentAvailable = aps["content-available"] as? Int, contentAvailable == 1 {
                // This is a silent push, nothing implemented but logging for now

                if let commandStatus = userInfo["command_status"] as? String {
                    LogManager.shared.log(category: .general, message: "Command status: \(commandStatus)")
                }

                if let commandType = userInfo["command_type"] as? String {
                    LogManager.shared.log(category: .general, message: "Command type: \(commandType)")
                }
            }
        }

        // Call completion handler
        completionHandler(.newData)
    }

    // MARK: UISceneSession Lifecycle

    func application(_: UIApplication, willFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // set the "prevent screen lock" option when the app is started
        // This method doesn't seem to be working anymore. Added to view controllers as solution offered on SO
        UIApplication.shared.isIdleTimerDisabled = Storage.shared.screenlockSwitchState.value

        return true
    }

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
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
            if let window = window {
                window.rootViewController?.dismiss(animated: true, completion: nil)
                window.rootViewController?.present(MainViewController(), animated: true, completion: nil)
            }
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
