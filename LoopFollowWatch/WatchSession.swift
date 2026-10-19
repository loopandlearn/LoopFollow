// LoopFollow
// WatchSession.swift

import Foundation
import WatchConnectivity
import WatchKit
import WidgetKit

/// Watch side of the phone link. Receives `WatchState` from the phone and sends
/// commands back for the phone to validate and relay.
@MainActor
final class WatchSession: NSObject, ObservableObject {
    static let shared = WatchSession()

    @Published private(set) var state: WatchState?
    @Published private(set) var isReachable = false

    private var session: WCSession { WCSession.default }

    override private init() {
        state = WatchStateStore.load()
        super.init()
    }

    func activate() {
        guard WCSession.isSupported(), session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    /// Asks the phone for fresh state; the application context covers the case
    /// where the phone is out of reach.
    func requestState() {
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([WatchMessageKey.requestState: true], replyHandler: { reply in
            guard let data = reply[WatchState.contextKey] as? Data else { return }
            Task { @MainActor in self.apply(data) }
        }, errorHandler: nil)
    }

    /// Sends a command to the phone and waits for its verdict. The phone has to be
    /// reachable: a command is never queued for later delivery.
    func send(_ action: WatchCommand.Action) async -> WatchCommandReply {
        guard session.activationState == .activated, session.isReachable else {
            return WatchCommandReply(success: false, message: "iPhone not reachable. Open LoopFollow on the iPhone and keep it near the watch.")
        }
        guard let data = try? JSONEncoder().encode(WatchCommand(action: action)) else {
            return WatchCommandReply(success: false, message: "Could not encode the command.")
        }
        return await withCheckedContinuation { continuation in
            session.sendMessage([WatchCommand.messageKey: data], replyHandler: { reply in
                let result = (reply[WatchCommandReply.messageKey] as? Data)
                    .flatMap { try? JSONDecoder().decode(WatchCommandReply.self, from: $0) }
                continuation.resume(returning: result ?? WatchCommandReply(success: false, message: "Unexpected reply from the iPhone."))
            }, errorHandler: { error in
                continuation.resume(returning: WatchCommandReply(
                    success: false,
                    message: "No reply from the iPhone (\(error.localizedDescription)). Check LoopFollow on the iPhone before trying again."
                ))
            })
        }
    }

    /// Lets a WatchConnectivity background task finish once queued data has been delivered.
    func waitForPendingContent() async {
        activate()
        for _ in 0 ..< 40 {
            if session.activationState == .activated, !session.hasContentPending { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func apply(_ data: Data) {
        guard let incoming = WatchState.decode(data) else { return }
        if let current = state, current.builtAt > incoming.builtAt { return }

        let newAlarm = incoming.alarm != nil && incoming.alarm?.id != state?.alarm?.id
        state = incoming
        WatchStateStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()

        if newAlarm, WKApplication.shared().applicationState == .active {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

extension WatchSession: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {
        let context = session.receivedApplicationContext[WatchState.contextKey] as? Data
        let reachable = session.isReachable
        Task { @MainActor in
            if let context { self.apply(context) }
            self.isReachable = reachable
            self.requestState()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if reachable { self.requestState() }
        }
    }

    nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchState.contextKey] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }

    nonisolated func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchState.contextKey] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
