//
//  WatchConnectivityManager.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-03-10.
//  Copyright © 2026 Jon Fawcett. All rights reserved.
//


// WatchConnectivityManager.swift
// Philippe Achkar
// 2026-03-10

import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject {

    // MARK: - Shared Instance

    static let shared = WatchConnectivityManager()

    // MARK: - Init

    /// Timestamp of the last snapshot the Watch ACK'd via sendAck().
    private var lastWatchAckTimestamp: TimeInterval = 0

    private override init() {
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
            try? session.updateApplicationContext(payload)
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
        }
    }

    /// When the Watch app comes to the foreground, send the latest snapshot immediately
    /// so the Watch app has fresh data without waiting for the next BG poll.
    /// Receives ACKs from the Watch (sent after each snapshot is saved).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let ackTimestamp = message["watchAck"] as? TimeInterval {
            lastWatchAckTimestamp = ackTimestamp
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch ACK received for snapshot at \(ackTimestamp)")
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let ackTimestamp = userInfo["watchAck"] as? TimeInterval {
            lastWatchAckTimestamp = ackTimestamp
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch ACK (userInfo) received for snapshot at \(ackTimestamp)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        if let snapshot = GlucoseSnapshotStore.shared.load() {
            send(snapshot: snapshot)
            LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: Watch became reachable — snapshot pushed")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        LogManager.shared.log(category: .watch, message: "WatchConnectivityManager: session deactivated — reactivating")
        WCSession.default.activate()
    }
}