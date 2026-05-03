// LoopFollow
// WatchSessionManager.swift

import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var config: WatchConfig?

    private override init() {
        super.init()
        // Load cached config on startup
        config = WatchConfig.loadFromDefaults()
    }

    func startSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Request the iPhone app to re-send its config via all available channels
    func requestConfigFromPhone() {
        guard WCSession.default.activationState == .activated else { return }

        // sendMessage is the fastest path — works if iPhone app is reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["requestConfig": true], replyHandler: { reply in
                // iPhone may reply with config directly
                if reply["nsURL"] != nil || reply["dexUsername"] != nil {
                    self.handleReceivedConfig(reply)
                }
            }, errorHandler: { _ in })
        }

        // transferUserInfo is queued and delivered even if iPhone app isn't running
        WCSession.default.transferUserInfo(["requestConfig": true])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
            return
        }

        // On activation, check for any previously sent application context
        let received = session.receivedApplicationContext
        if !received.isEmpty, received["nsURL"] != nil || received["dexUsername"] != nil {
            handleReceivedConfig(received)
        }

        // Always request config from iPhone — covers fresh install and stale cache
        if config == nil {
            requestConfigFromPhone()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReceivedConfig(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleReceivedConfig(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedConfig(message)
    }

    private func handleReceivedConfig(_ dict: [String: Any]) {
        // Ignore if this is a requestConfig message from Watch itself
        guard dict["requestConfig"] == nil else { return }
        // Ignore if it doesn't look like a config (needs at least one data source key)
        guard dict["nsURL"] != nil || dict["dexUsername"] != nil else { return }

        let newConfig = WatchConfig(from: dict)
        newConfig.saveToDefaults()
        DispatchQueue.main.async {
            self.config = newConfig
        }
    }
}
