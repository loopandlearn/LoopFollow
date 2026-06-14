// LoopFollow
// AppDelegate.swift

import AVFoundation
import EventKit
import UIKit
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
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

        // Telemetry: record this cold launch (used by the rolling
        // coldLaunches7d signal). If the running build's SHA differs from
        // the one we last sent for, fire an immediate ping — the scheduler
        // alone can't notice an app update. Otherwise let the 24h scheduler
        // handle cadence: its first run is lastSentAt + 24h, so a relaunch
        // a few hours after the previous send simply waits out the
        // remainder. See Helpers/Telemetry.swift.
        TelemetryClient.shared.recordColdLaunch()
        Task.detached {
            if TelemetryClient.shared.buildShaChangedSinceLastSend() {
                await TelemetryClient.shared.maybeSend()
            }
            TelemetryClient.shared.scheduleRecurring()
        }

        // Detect Before-First-Unlock launch. If protected data is unavailable here,
        // StorageValues were cached from encrypted UserDefaults and need a reload
        // once the device is unlocked.
        let bfu = !UIApplication.shared.isProtectedDataAvailable
        Storage.shared.needsBFUReload = bfu
        LogManager.shared.log(category: .general, message: "BFU check: isProtectedDataAvailable=\(!bfu), needsBFUReload=\(bfu)")

        // Recovery is driven from AppDelegate (not MainViewController) because under
        // the SwiftUI App lifecycle the home tab's UIHostingController is materialized
        // lazily — on a BG-only launch (BGAppRefreshTask, BLE wake) MainViewController
        // may not exist when the device is unlocked, and would miss willEnterForeground.
        // protectedDataDidBecomeAvailable fires the moment file protection lifts and
        // is the authoritative signal; willEnterForeground is a fallback.
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(protectedDataDidBecomeAvailable), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        // Race guard: protected data may have become available between the check
        // above and the observer registration just now.
        if Storage.shared.needsBFUReload, UIApplication.shared.isProtectedDataAvailable {
            performBFUReloadIfNeeded()
        }

        return true
    }

    // MARK: - BFU recovery

    @objc private func protectedDataDidBecomeAvailable() {
        performBFUReloadIfNeeded()
    }

    @objc private func handleWillEnterForeground() {
        performBFUReloadIfNeeded()
    }

    private func performBFUReloadIfNeeded() {
        guard Storage.shared.needsBFUReload else { return }
        Storage.shared.needsBFUReload = false
        LogManager.shared.log(category: .general, message: "BFU reload triggered — reloading all StorageValues")
        Storage.shared.reloadAll()
        LogManager.shared.log(category: .general, message: "BFU reload complete: url='\(Storage.shared.url.value)'")
        NotificationCenter.default.post(name: .bfuReloadCompleted, object: nil)
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

        LogManager.shared.log(category: .apns, message: "Successfully registered for remote notifications with token: \(LogRedactor.tail(tokenString))")
    }

    /// Called when failed to register for remote notifications
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        LogManager.shared.log(category: .apns, message: "Failed to register for remote notifications: \(error.localizedDescription)")
    }

    /// Called when a remote notification is received
    func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let userInfoKeys = userInfo.keys.compactMap { $0 as? String }.sorted()
        LogManager.shared.log(category: .apns, message: "Received remote notification: keys=\(userInfoKeys)")

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

    // MARK: - Scene configuration

    // Under the scene-based lifecycle (which the SwiftUI App lifecycle uses),
    // UIKit delivers Home Screen quick actions and opened URLs to the window
    // scene delegate — application(_:performActionFor:) is never called.
    // Injecting a delegate class here is the supported way to receive those
    // events; SwiftUI still creates and manages the window itself.
    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = AppSceneDelegate.self
        }
        return configuration
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "OPEN_APP_ACTION" {
            // Dismiss any presented modal/sheet so the user actually sees Home
            UIApplication.shared.topMost?.dismiss(animated: true)
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

extension Notification.Name {
    /// Posted by AppDelegate after a Before-First-Unlock recovery completes
    /// (Storage.reloadAll has run with the now-decrypted UserDefaults).
    static let bfuReloadCompleted = Notification.Name("LoopFollow.bfuReloadCompleted")
}

/// Window scene delegate installed via configurationForConnecting. SwiftUI owns
/// the window; this class only handles the events UIKit routes to the scene
/// delegate instead of the application delegate.
final class AppSceneDelegate: NSObject, UIWindowSceneDelegate {
    private let speechSynthesizer = AVSpeechSynthesizer()

    /// A quick action used to cold-launch the app arrives in the connection
    /// options; windowScene(_:performActionFor:) is not called for that launch.
    func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
    }

    /// Called when the user taps the "Speak BG" Home Screen quick action while
    /// the app is already running.
    func windowScene(_: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcutItem(shortcutItem))
    }

    @discardableResult
    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              shortcutItem.type == bundleIdentifier + ".toggleSpeakBG"
        else {
            return false
        }
        Storage.shared.speakBG.value.toggle()
        let message = Storage.shared.speakBG.value ? "BG Speak is now on" : "BG Speak is now off"
        speechSynthesizer.speak(AVSpeechUtterance(string: message))
        return true
    }

    /// With a custom scene delegate installed, UIKit delivers opened URLs here
    /// rather than through SwiftUI's onOpenURL, so the Live Activity tap
    /// handling from LoopFollowApp is mirrored. Posting twice is harmless —
    /// the navigation it triggers is idempotent.
    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard URLContexts.contains(where: { $0.url.scheme == AppGroupID.urlScheme && $0.url.host == "la-tap" }) else { return }
        #if !targetEnvironment(macCatalyst)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .liveActivityDidForeground, object: nil)
            }
        #endif
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let content = notification.request.content
        let userInfoKeys = content.userInfo.keys.compactMap { $0 as? String }.sorted()
        LogManager.shared.log(
            category: .general,
            message: "Will present notification: keys=\(userInfoKeys), interruption=\(content.interruptionLevel.rawValue), title=\(content.title.isEmpty ? "empty" : "set"), body=\(content.body.isEmpty ? "empty" : "set")"
        )

        // Suppress notifications iOS routes here that we never intended to surface:
        // the Live Activity push-to-start uses interruption-level: passive with empty
        // title/body and must not produce a banner or sound when LF is foregrounded.
        if content.interruptionLevel == .passive || (content.title.isEmpty && content.body.isEmpty) {
            completionHandler([])
            return
        }

        completionHandler([.banner, .sound, .badge])
    }
}
