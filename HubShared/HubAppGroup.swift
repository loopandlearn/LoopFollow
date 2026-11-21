// LoopFollow
// HubAppGroup.swift

/// What the app shares with LoopFollowNotificationService through the App Group's
/// defaults. The device key is not shared: the extension's one hub call, the
/// delivery receipt, needs no key.
enum HubAppGroup {
    /// The hub's address while the app is connected to a hub; absent otherwise.
    static let hubURLKey = "lfhubURL"

    /// The notification category of a hub alarm whose snooze is 0: its buttons read
    /// Acknowledge, as the app's own action for such an alarm does.
    static let acknowledgeCategory = "lfhub-ack"

    /// How the extension delivers a push from the hub.
    enum Delivery: Equatable {
        /// As a system alarm, when the hub asks for one.
        case systemAlarm
        /// As the notification the hub sent, with its sound.
        case notification
        /// Quietly to the notification list, with no sound: this phone has left the hub,
        /// so nothing it cannot silence rings, and the push is still kept.
        case quiet
    }

    /// A push reaching a phone that is not connected to a hub (`hubURL` absent) is
    /// delivered quietly.
    static func delivery(hubURL: String?, systemAlarm: Bool) -> Delivery {
        guard let hubURL, !hubURL.isEmpty else { return .quiet }
        return systemAlarm ? .systemAlarm : .notification
    }
}
