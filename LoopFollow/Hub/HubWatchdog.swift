// LoopFollow
// HubWatchdog.swift

import Foundation
import UserNotifications

/// In LoopFollow Hub mode the phone checks now and then that the hub is still
/// alive and reaching it: on a background refresh, whenever the app comes to the
/// foreground, and while it is open. After `unhealthyTolerance` the app's own alarm
/// check runs again (and the app keeps itself running, as in Silent Tune). After
/// `silentAfter` without a healthy answer it raises one alert per outage: a system
/// alarm through silent mode when AlarmKit is allowed, otherwise a time-sensitive
/// notification. In every other mode it does nothing.
enum HubWatchdog {
    static let silentAfter: TimeInterval = 20 * 60
    /// Checks may fail this long before the app counts the hub as unhealthy.
    static let unhealthyTolerance: TimeInterval = 5 * 60

    private static let notificationID = "lfhub.watchdog"
    private static let alertID = UUID(uuidString: "6C1F5A2E-0B7D-4E4F-9F3A-48B1A1E0D0A1")!
    private static let alertTitle = "⚠️ LF Hub not responding"
    private static let alertSymbol = "exclamationmark.icloud"

    private static let lastHealthy = StorageValue<TimeInterval>(key: "hubWatchdogLastHealthy", defaultValue: 0)
    private static let alerted = StorageValue<Bool>(key: "hubWatchdogAlerted", defaultValue: false)
    private static let unhealthySince = StorageValue<TimeInterval>(key: "hubWatchdogUnhealthySince", defaultValue: 0)

    /// The watchdog's memory between checks, in Unix seconds; 0 means unset.
    struct State: Equatable {
        var lastHealthy: TimeInterval = 0
        var unhealthySince: TimeInterval = 0
        var alerted = false
    }

    enum Action: Equatable {
        case none
        case raiseAlert(minutes: Int)
        case clearAlert
    }

    /// False once checks have failed for `unhealthyTolerance`: the app then runs its
    /// own alarm check, alongside the hub.
    static var hubLooksHealthy: Bool {
        looksHealthy(currentState, now: Date().timeIntervalSince1970)
    }

    static func looksHealthy(_ state: State, now: TimeInterval) -> Bool {
        state.unhealthySince == 0 || now - state.unhealthySince < unhealthyTolerance
    }

    /// The state after a check that gave `health` at `now`, and what to do about it.
    /// The first unhealthy check without an earlier healthy one starts the clock.
    static func next(_ state: State, hubMode: Bool, health: HubClient.Health,
                     now: TimeInterval) -> (state: State, action: Action)
    {
        guard hubMode else { return (State(), state.alerted ? .clearAlert : .none) }
        var state = state
        switch health {
        case .unknown:
            return (state, .none)
        case .healthy:
            let action: Action = state.alerted ? .clearAlert : .none
            state = State(lastHealthy: now, unhealthySince: 0, alerted: false)
            return (state, action)
        case .unhealthy:
            if state.unhealthySince == 0 { state.unhealthySince = now }
            if state.lastHealthy == 0 { state.lastHealthy = now }
            let silentFor = now - state.lastHealthy
            guard silentFor >= silentAfter, !state.alerted else { return (state, .none) }
            state.alerted = true
            return (state, .raiseAlert(minutes: Int(silentFor / 60)))
        }
    }

    private static var currentState: State {
        State(lastHealthy: lastHealthy.value, unhealthySince: unhealthySince.value, alerted: alerted.value)
    }

    @MainActor
    static func check() async {
        await HubClient.shared.readNotificationPermission()
        let hubMode = HubClient.shared.isHubMode
        let health: HubClient.Health = hubMode ? await HubClient.shared.health() : .unknown
        let wasHealthy = hubLooksHealthy
        let (state, action) = next(currentState, hubMode: hubMode, health: health,
                                   now: Date().timeIntervalSince1970)
        lastHealthy.value = state.lastHealthy
        unhealthySince.value = state.unhealthySince
        alerted.value = state.alerted

        if health == .unhealthy {
            let silentFor = Int((Date().timeIntervalSince1970 - state.lastHealthy) / 60)
            LogManager.shared.log(category: .hub, message: "Hub watchdog: no healthy answer for \(silentFor) min")
        }
        if wasHealthy, !hubLooksHealthy {
            LogManager.shared.log(category: .hub, message: "Hub watchdog: hub unhealthy; the app alarms itself")
        }
        switch action {
        case .none:
            break
        case let .raiseAlert(minutes):
            await raiseAlert(minutes: minutes)
        case .clearAlert:
            clearAlert()
            LogManager.shared.log(category: .hub, message: hubMode ? "Hub watchdog: hub healthy again" : "Hub watchdog: alert cleared")
        }
    }

    private static func raiseAlert(minutes: Int) async {
        LogManager.shared.log(category: .hub, message: "Hub watchdog: alerting after \(minutes) min")
        #if !targetEnvironment(macCatalyst)
            if #available(iOS 26, *),
               await HubAlarmKit.ringNotice(id: alertID, title: alertTitle, symbol: alertSymbol)
            {
                return
            }
        #endif
        let content = UNMutableNotificationContent()
        content.title = alertTitle
        content.body = "No working connection to LF Hub for \(minutes) minutes, so its alarms may not reach this phone. Open LoopFollow."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: notificationID, content: content, trigger: nil)
        )
    }

    private static func clearAlert() {
        #if !targetEnvironment(macCatalyst)
            if #available(iOS 26, *) { HubAlarmKit.stop(alarmID: alertID) }
        #endif
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
    }
}
