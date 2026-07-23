// LoopFollow
// NotificationAuthorization.swift

import UserNotifications

/// Requests notification authorization lazily, the first time the user opts into
/// a feature that needs it (alarms). This keeps the system prompt off the very
/// first launch so it doesn't front the onboarding flow.
enum NotificationAuthorization {
    /// Asks for authorization only when the user hasn't decided yet. Safe to call
    /// repeatedly — it's a no-op once the status is determined. `completion` runs
    /// on the main queue after the prompt is dismissed (or immediately when the
    /// status was already determined), so a caller can wait for the system prompt
    /// before moving on.
    static func requestIfNeeded(completion: @escaping () -> Void = {}) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                DispatchQueue.main.async { completion() }
                return
            }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                if !granted {
                    LogManager.shared.log(category: .general, message: "User has declined notifications")
                }
                DispatchQueue.main.async { completion() }
            }
        }
    }
}
