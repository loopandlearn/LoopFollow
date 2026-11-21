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
    ///
    /// iOS takes a ringing alarm's banner, with its button, away when LoopFollow leaves
    /// the screen, and the alarm sounds on without it. The app therefore rings its
    /// sounding hub alarms again when it goes to the background, and the extension rings
    /// a sounding one again when LoopFollow ended while on screen.
    @available(iOS 26, *)
    enum HubAlarmKit {
        /// A fixed alarm at or before now never fires, so it is set this far ahead.
        private static let immediateFireDelay: TimeInterval = 2

        /// What a hub alarm was last rung with, so it can be rung again.
        private struct Ringing: Codable {
            let title: String
            let soundName: String?
            let symbol: String
            let acknowledge: Bool
        }

        /// The App Group defaults key of a hub alarm rung and not stopped, one per alarm, so
        /// the app and the extension never overwrite each other's.
        private static func ringingKey(_ alarmID: UUID) -> String { "lfhubAlarmRinging.\(alarmID.uuidString)" }

        /// The App Group defaults key of when LoopFollow last said it is on screen (Unix
        /// seconds), 0 once it left the screen.
        private static let onScreenKey = "lfhubAppOnScreenAt"

        /// The app refreshes its on-screen time at each minute's alarm check; one this old
        /// means LoopFollow ended while on screen.
        private static let onScreenStale: TimeInterval = 150

        private static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroupID.current()) }

        private static func ringing(_ alarmID: UUID) -> Ringing? {
            defaults?.data(forKey: ringingKey(alarmID)).flatMap { try? JSONDecoder().decode(Ringing.self, from: $0) }
        }

        private static func setRinging(_ value: Ringing?, for alarmID: UUID) {
            if let value, let data = try? JSONEncoder().encode(value) {
                defaults?.set(data, forKey: ringingKey(alarmID))
            } else {
                defaults?.removeObject(forKey: ringingKey(alarmID))
            }
        }

        /// The app records that it is on screen, where a system alarm's banner does not
        /// outlast it, and refreshes that while it stays there.
        static func setOnScreen(_ onScreen: Bool) {
            defaults?.set(onScreen ? Date().timeIntervalSince1970 : 0, forKey: onScreenKey)
        }

        /// LoopFollow said it is on screen and has not refreshed that since: it ended there.
        private static var endedOnScreen: Bool {
            let at = defaults?.double(forKey: onScreenKey) ?? 0
            return at > 0 && Date().timeIntervalSince1970 - at > onScreenStale
        }

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
        /// `again` rings an alarm that already rings, with a new banner.
        static func ring(alarmID: UUID, title: String, soundName: String?, symbol: String = "moon.zzz",
                         acknowledge: Bool = false, again: Bool = false) async
            -> (ringing: Bool, firesAt: Date?, detail: String)
        {
            // A denied state is final; notDetermined is what an extension reads even
            // after the app was authorized, so scheduling is attempted then too.
            let state = AlarmKit.AlarmManager.shared.authorizationState
            guard state != .denied else { return (false, nil, "authorization denied") }
            var rungAgain = ""
            if let existing = ((try? AlarmKit.AlarmManager.shared.alarms) ?? []).first(where: { $0.id == alarmID }) {
                // LoopFollow ended while on screen: the alarm sounds on without its banner.
                let bannerLost = endedOnScreen
                guard again || bannerLost else {
                    return (true, nil, existing.state == .alerting ? "already ringing" : "already scheduled")
                }
                if bannerLost { setOnScreen(false) }
                rungAgain = ", rung again from state \(existing.state)\(bannerLost ? " after LoopFollow ended on screen" : "")"
                stopAlarmKit(alarmID)
            } else if endedOnScreen {
                // This alarm gets its banner; one rung later must not count the app as on screen.
                setOnScreen(false)
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
                setRinging(Ringing(title: title, soundName: soundName, symbol: symbol, acknowledge: acknowledge),
                           for: alarmID)
                return (true, firesAt, "scheduled, state \(alarm.state) (authorization read \(state))\(rungAgain)")
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
            stopAlarmKit(alarmID)
            setRinging(nil, for: alarmID)
        }

        private static func stopAlarmKit(_ alarmID: UUID) {
            try? AlarmKit.AlarmManager.shared.stop(id: alarmID)
            try? AlarmKit.AlarmManager.shared.cancel(id: alarmID)
        }

        /// Rings each sounding hub alarm again, so it gets back the banner and button iOS
        /// took away when LoopFollow left the screen. Returns how many were rung again and
        /// what went wrong with the others.
        static func ringSoundingAgain() async -> (count: Int, failures: [String]) {
            var count = 0
            var failures: [String] = []
            for alarm in (try? AlarmKit.AlarmManager.shared.alarms) ?? [] where alarm.state == .alerting {
                guard let ringing = ringing(alarm.id) else { continue }
                let result = await ring(alarmID: alarm.id, title: ringing.title, soundName: ringing.soundName,
                                        symbol: ringing.symbol, acknowledge: ringing.acknowledge, again: true)
                if result.ringing { count += 1 } else { failures.append("\(alarm.id.uuidString.prefix(8)): \(result.detail)") }
            }
            return (count, failures)
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
