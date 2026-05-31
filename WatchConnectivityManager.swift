// LoopFollow
// WatchConnectivityManager.swift

import Combine
import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject {
    // MARK: - Shared Instance

    static let shared = WatchConnectivityManager()

    // MARK: - Init

    /// Timestamp of the last snapshot the Watch ACK'd via sendAck().
    private var lastWatchAckTimestamp: TimeInterval = 0
    /// Timestamp of the last remote command received from the Watch.
    private var lastWatchCommandDate: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
    }

    // MARK: - Setup

    /// Call once from AppDelegate after app launch.
    func activate() {
        guard WCSession.isSupported() else {
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        observeLoopAPNSSettings()
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: WCSession activation requested")
    }

    // MARK: - Send Snapshot

    /// Sends the latest GlucoseSnapshot to the Watch via transferUserInfo.
    /// Safe to call from any thread.
    /// No-ops silently if Watch is not paired or reachable.
    func send(snapshot: GlucoseSnapshot) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default

        guard session.activationState == .activated else {
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: session not activated, skipping send")
            return
        }

        guard session.isPaired else {
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: no paired Watch, skipping send")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            let payload: [String: Any] = ["snapshot": data]

            // Warn if Watch hasn't ACK'd this or a recent snapshot.
            let behindBy = snapshot.updatedAt.timeIntervalSince1970 - lastWatchAckTimestamp
            if lastWatchAckTimestamp > 0, behindBy > 600 {
                LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch ACK is \(Int(behindBy))s behind — Watch may be missing deliveries")
            }

            // sendMessage: immediate delivery when Watch app is in foreground.
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
                LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: snapshot sent via sendMessage (reachable)")
            }

            // Cancel outstanding transfers before queuing — only the latest snapshot matters.
            session.outstandingUserInfoTransfers.forEach { $0.cancel() }

            // transferUserInfo: guaranteed queued delivery for background wakes.
            session.transferUserInfo(payload)

            // applicationContext: latest-state mirror for next launch / scheduled refresh.
            do {
                try session.updateApplicationContext(payload)
            } catch {
                LogManager.shared.log(
                    category: .watch,
                    message: "WatchConnectivityManager: failed to update applicationContext — \(error)"
                )
            }

            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: snapshot queued via transferUserInfo")
        } catch {
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: failed to encode snapshot — \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: activation failed — \(error)")
        } else {
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: activation complete — state \(activationState.rawValue)")
            syncWatchAppGroupSettings()
            notifyWatchSettingsChanged()
        }
    }

    /// When the Watch app comes to the foreground, send the latest snapshot immediately
    /// so the Watch app has fresh data without waiting for the next BG poll.
    /// Receives ACKs from the Watch (sent after each snapshot is saved).
    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        if let ackTimestamp = message["watchAck"] as? TimeInterval {
            lastWatchAckTimestamp = ackTimestamp
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch ACK received for snapshot at \(ackTimestamp)")
        }
    }

    /// Handles remote command messages sent from the Watch with a reply handler.
    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: received Watch command — \(message["watchCmd"] as? String ?? "unknown")")
        lastWatchCommandDate = Date()
        WatchCommandDispatcher.shared.handle(message: message, replyHandler: replyHandler)
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let ackTimestamp = userInfo["watchAck"] as? TimeInterval {
            lastWatchAckTimestamp = ackTimestamp
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch ACK (userInfo) received for snapshot at \(ackTimestamp)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        syncWatchAppGroupSettings()
        notifyWatchSettingsChanged()
        if let snapshot = GlucoseSnapshotStore.shared.load() {
            send(snapshot: snapshot)
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch became reachable — snapshot pushed")
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: session became inactive")
    }

    func sessionDidDeactivate(_: WCSession) {
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: session deactivated — reactivating")
        WCSession.default.activate()
    }

    // MARK: - App Group sync

    private func syncWatchAppGroupSettings() {
        LAAppGroupSettings.setWatchRemoteEnabled(LoopAPNSService().validateSetup())
        LAAppGroupSettings.setWatchMaxBolus(Storage.shared.maxBolus.value.doubleValue(for: .internationalUnit()))
        LAAppGroupSettings.setWatchMaxCarbs(Storage.shared.maxCarbs.value.doubleValue(for: .gram()))
    }

    /// Notifies the Watch to re-read App Group settings (e.g. after LoopAPNS is configured).
    private func notifyWatchSettingsChanged() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isReachable else { return }
        session.sendMessage(["watchSettingsRefresh": true], replyHandler: nil, errorHandler: nil)
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: settings refresh sent to Watch")
    }

    /// Forwards a Loop command return notification to the Watch as a local notification trigger.
    /// Called from AppDelegate when a remote notification arrives. Forwards if:
    ///   - the notification contains command_status/command_type (Loop explicit fields), OR
    ///   - a Watch command was dispatched within the last 2 minutes (time-window correlation).
    func forwardCommandReturnToWatch(userInfo: [AnyHashable: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired else { return }

        let hasCommandFields = userInfo["command_status"] != nil || userInfo["command_type"] != nil
        let recentWatchCommand = Date().timeIntervalSince(lastWatchCommandDate) < 120
        let hasAlert: Bool = {
            guard let aps = userInfo["aps"] as? [String: Any] else { return false }
            return aps["alert"] != nil
        }()

        guard hasCommandFields || (recentWatchCommand && hasAlert) else { return }

        var title = "Loop Confirmed ✓"
        var body = "Command processed by Loop"

        if let commandType = userInfo["command_type"] as? String {
            switch commandType.lowercased() {
            case "bolus": title = "Bolus Confirmed ✓"
            case "carbs": title = "Carbs Confirmed ✓"
            case "override": title = "Override Confirmed ✓"
            default: break
            }
        }

        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                title = alert["title"] as? String ?? title
                body = alert["body"] as? String ?? body
            } else if let alertStr = aps["alert"] as? String {
                body = alertStr
            }
        }

        let payload: [String: Any] = ["watchLoopReturn": true, "title": title, "body": body]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: forwarded Loop return to Watch — \(title)")
    }

    /// Observes LoopAPNS-relevant storage values and syncs to App Group whenever they change.
    private func observeLoopAPNSSettings() {
        Publishers.MergeMany(
            Storage.shared.deviceToken.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.loopAPNSQrCodeURL.$value.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            Storage.shared.remoteApnsKey.$value.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] in
            self?.syncWatchAppGroupSettings()
            self?.notifyWatchSettingsChanged()
        }
        .store(in: &cancellables)
    }
}
