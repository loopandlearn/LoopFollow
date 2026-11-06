// LoopFollow
// HubAlarmKit.swift

// Compiled into the app and into LoopFollowNotificationService only: the extension
// rings hub alarms through it; the app stops them, handles their snooze intent and
// rings its own notices.

import Foundation

#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
    import ActivityKit
    import AlarmKit
    import AppIntents
    import struct SwiftUI.Color

    /// Rings an alarm LF Hub delivered as an AlarmKit alarm, which breaks through
    /// the silent switch and Focus. The notification service extension calls this
    /// for every hub alarm push, so it rings even while LoopFollow is suspended
    /// or not running. The AlarmKit alarm takes the LoopFollow alarm's id, so a
    /// repeated push for an alarm that is still ringing does not ring twice.
    @available(iOS 26, *)
    enum HubAlarmKit {
        /// A fixed alarm at or before now never fires, so it is set this far ahead.
        private static let immediateFireDelay: TimeInterval = 2

        static var isAuthorized: Bool {
            AlarmKit.AlarmManager.shared.authorizationState == .authorized
        }

        /// The user has not been asked yet; once asked, only the Settings app changes it.
        static var canAsk: Bool {
            AlarmKit.AlarmManager.shared.authorizationState == .notDetermined
        }

        static func requestAuthorization() async -> Bool {
            if AlarmKit.AlarmManager.shared.authorizationState == .notDetermined {
                _ = try? await AlarmKit.AlarmManager.shared.requestAuthorization()
            }
            return isAuthorized
        }

        /// Whether the alarm is ringing or about to, when it starts if this call scheduled it,
        /// and why. Not ringing when AlarmKit is not authorized or scheduling failed, so the
        /// notification keeps its sound. Without `soundName` it rings with the default sound.
        /// `symbol` is the SF Symbol on the alarm's button: the alarm type's icon. The button
        /// reads Acknowledge for an alarm whose snooze is 0 (`acknowledge`), as in the app.
        static func ring(alarmID: UUID, title: String, soundName: String?, symbol: String = "moon.zzz",
                         acknowledge: Bool = false) async -> (ringing: Bool, firesAt: Date?, detail: String)
        {
            // A denied state is final; notDetermined is what an extension reads even
            // after the app was authorized, so scheduling is attempted then too.
            let state = AlarmKit.AlarmManager.shared.authorizationState
            guard state != .denied else { return (false, nil, "authorization denied") }
            if ((try? AlarmKit.AlarmManager.shared.alarms) ?? []).contains(where: { $0.id == alarmID }) {
                return (true, nil, "already scheduled")
            }

            let presentation = AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: title),
                    stopButton: AlarmButton(
                        text: LocalizedStringResource(stringLiteral: buttonTitle(acknowledge: acknowledge)),
                        textColor: .white,
                        systemImageName: symbol
                    )
                )
            )
            let firesAt = Date().addingTimeInterval(immediateFireDelay)
            let configuration = AlarmKit.AlarmManager.AlarmConfiguration<HubAlarmMetadata>.alarm(
                schedule: .fixed(firesAt),
                attributes: AlarmAttributes(presentation: presentation, tintColor: .red),
                stopIntent: SnoozeHubAlarmIntent(alarmID: alarmID),
                sound: soundName.map { .named($0) } ?? .default
            )
            do {
                let alarm = try await AlarmKit.AlarmManager.shared.schedule(id: alarmID, configuration: configuration)
                return (true, firesAt, "scheduled, state \(alarm.state) (authorization read \(state))")
            } catch {
                return (false, nil, "schedule failed with authorization \(state): \(error)")
            }
        }

        static func buttonTitle(acknowledge: Bool) -> String {
            acknowledge ? "Acknowledge" : "Snooze"
        }

        /// Rings a notice from the app itself (not a LoopFollow alarm) as a system
        /// alarm now, with an OK button and no snooze. Replaces a notice with the same id.
        static func ringNotice(id: UUID, title: String, symbol: String) async -> Bool {
            guard AlarmKit.AlarmManager.shared.authorizationState == .authorized else { return false }
            stop(alarmID: id)
            let presentation = AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: title),
                    stopButton: AlarmButton(
                        text: LocalizedStringResource(stringLiteral: "OK"),
                        textColor: .white,
                        systemImageName: symbol
                    )
                )
            )
            let configuration = AlarmKit.AlarmManager.AlarmConfiguration<HubAlarmMetadata>.alarm(
                schedule: .fixed(Date().addingTimeInterval(immediateFireDelay)),
                attributes: AlarmAttributes(presentation: presentation, tintColor: .orange),
                sound: .default
            )
            return (try? await AlarmKit.AlarmManager.shared.schedule(id: id, configuration: configuration)) != nil
        }

        /// Whether the alarm is sounding now.
        static func isAlerting(alarmID: UUID) -> Bool {
            ((try? AlarmKit.AlarmManager.shared.alarms) ?? []).contains { $0.id == alarmID && $0.state == .alerting }
        }

        static func stop(alarmID: UUID) {
            try? AlarmKit.AlarmManager.shared.stop(id: alarmID)
            try? AlarmKit.AlarmManager.shared.cancel(id: alarmID)
        }
    }

    @available(iOS 26, *)
    struct HubAlarmMetadata: AlarmMetadata {}

    /// Runs in the app when the AlarmKit alarm's button is tapped, and snoozes
    /// the LoopFollow alarm the way the notification's snooze action does.
    @available(iOS 26, *)
    struct SnoozeHubAlarmIntent: LiveActivityIntent {
        static let title: LocalizedStringResource = "Snooze LoopFollow Alarm"
        static let isDiscoverable = false

        @Parameter(title: "Alarm ID") var alarmID: String

        init() {}

        init(alarmID: UUID) {
            self.alarmID = alarmID.uuidString
        }

        func perform() async throws -> some IntentResult {
            if let id = UUID(uuidString: alarmID) {
                await HubAlarmSnoozeBridge.shared.snooze(id)
            }
            return .result()
        }
    }
#endif

/// Hands an AlarmKit snooze to the app's alarm handling. Taps that arrive
/// before the app registers its handler are queued until it does.
@MainActor
final class HubAlarmSnoozeBridge {
    static let shared = HubAlarmSnoozeBridge()
    private init() {}

    private var handler: (@MainActor (UUID) async -> Void)?
    private var pending: [UUID] = []

    func setHandler(_ handler: @escaping @MainActor (UUID) async -> Void) {
        self.handler = handler
        let queued = pending
        pending = []
        Task { for id in queued {
            await handler(id)
        } }
    }

    func snooze(_ id: UUID) async {
        if let handler {
            await handler(id)
        } else {
            pending.append(id)
        }
    }
}
