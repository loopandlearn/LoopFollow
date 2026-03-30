// WatchSessionReceiver.swift
// Philippe Achkar
// 2026-03-10

import Foundation
import WatchConnectivity
import ClockKit
import WatchKit
import os.log

private let watchLog = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? "com.loopfollow.watch",
    category: "Watch"
)

final class WatchSessionReceiver: NSObject {

    // MARK: - Shared Instance

    static let shared = WatchSessionReceiver()

    static let snapshotReceivedNotification = Notification.Name("WatchSnapshotReceived")

    /// Held open while WatchConnectivity delivers a pending transferUserInfo in the background.
    /// Completed after the snapshot is saved to disk.
    var pendingConnectivityTask: WKWatchConnectivityRefreshBackgroundTask?

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Call once from the Watch extension entry point after launch.
    func activate() {
        guard WCSession.isSupported() else {
            os_log("WatchSessionReceiver: WCSession not supported", log: watchLog, type: .debug)
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        os_log("WatchSessionReceiver: WCSession activation requested", log: watchLog, type: .debug)
    }

    /// Triggers a complication timeline reload. Called from background refresh tasks
    /// after a snapshot has already been saved to GlucoseSnapshotStore.
    func triggerComplicationReload() {
        reloadComplications()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionReceiver: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            os_log("WatchSessionReceiver: activation failed — %{public}@", log: watchLog, type: .error, error.localizedDescription)
        } else {
            os_log("WatchSessionReceiver: activation complete — state %d", log: watchLog, type: .debug, activationState.rawValue)
            bootstrapFromApplicationContext(session)
        }
    }

    /// Loads a snapshot from the last received applicationContext so the Watch app
    /// has data immediately on launch without waiting for the next transferUserInfo.
    private func bootstrapFromApplicationContext(_ session: WCSession) {
        guard let data = session.receivedApplicationContext["snapshot"] as? Data else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(GlucoseSnapshot.self, from: data)
            GlucoseSnapshotStore.shared.save(snapshot) { [weak self] in
                os_log("WatchSessionReceiver: bootstrapped snapshot from applicationContext", log: watchLog, type: .debug)
                self?.reloadComplications()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: WatchSessionReceiver.snapshotReceivedNotification,
                        object: nil,
                        userInfo: ["snapshot": snapshot]
                    )
                }
            }
        } catch {
            os_log("WatchSessionReceiver: failed to decode applicationContext snapshot — %{public}@", log: watchLog, type: .error, error.localizedDescription)
        }
    }

    /// Handles immediate delivery when Watch app is in foreground (sendMessage path).
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        process(payload: message, source: "sendMessage")
    }

    /// Handles queued background delivery (transferUserInfo path).
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        process(payload: userInfo, source: "userInfo")
    }

    // MARK: - Private

    private func process(payload: [String: Any], source: String) {
        guard let data = payload["snapshot"] as? Data else {
            os_log("WatchSessionReceiver: %{public}@ — no snapshot key", log: watchLog, type: .debug, source)
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(GlucoseSnapshot.self, from: data)
            os_log("WatchSessionReceiver: %{public}@ snapshot decoded, saving", log: watchLog, type: .debug, source)
            GlucoseSnapshotStore.shared.save(snapshot) { [weak self] in
                os_log("WatchSessionReceiver: %{public}@ snapshot saved, reloading complications", log: watchLog, type: .debug, source)
                // ACK to iPhone so it can detect missed deliveries.
                self?.sendAck(for: snapshot)
                // Capture and clear the pending task before dispatching to main,
                // then complete it AFTER reloadTimeline() so watchOS doesn't suspend
                // the extension before ClockKit processes the reload request.
                let task = self?.pendingConnectivityTask
                self?.pendingConnectivityTask = nil
                DispatchQueue.main.async {
                    let server = CLKComplicationServer.sharedInstance()
                    if let complications = server.activeComplications, !complications.isEmpty {
                        for complication in complications { server.reloadTimeline(for: complication) }
                        os_log("WatchSessionReceiver: reloaded %d complication(s)", log: watchLog, type: .debug, complications.count)
                    } else {
                        os_log("WatchSessionReceiver: no active complications to reload", log: watchLog, type: .debug)
                    }
                    // Complete background task only after reloadTimeline() has been called.
                    task?.setTaskCompletedWithSnapshot(false)
                    NotificationCenter.default.post(
                        name: WatchSessionReceiver.snapshotReceivedNotification,
                        object: nil,
                        userInfo: ["snapshot": snapshot]
                    )
                }
            }
        } catch {
            os_log("WatchSessionReceiver: %{public}@ decode failed — %{public}@", log: watchLog, type: .error, source, error.localizedDescription)
        }
    }

    private func sendAck(for snapshot: GlucoseSnapshot) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let ack: [String: Any] = ["watchAck": snapshot.updatedAt.timeIntervalSince1970]
        if session.isReachable {
            session.sendMessage(ack, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(ack)
        }
        os_log("WatchSessionReceiver: ACK sent for snapshot at %f", log: watchLog, type: .debug, snapshot.updatedAt.timeIntervalSince1970)
    }

    private func reloadComplications() {
        DispatchQueue.main.async {
            let server = CLKComplicationServer.sharedInstance()
            guard let complications = server.activeComplications, !complications.isEmpty else {
                os_log("WatchSessionReceiver: no active complications to reload", log: watchLog, type: .debug)
                return
            }
            for complication in complications { server.reloadTimeline(for: complication) }
            os_log("WatchSessionReceiver: reloaded %d complication(s)", log: watchLog, type: .debug, complications.count)
        }
    }

    // NOTE: reloadComplications() is safe to call from any thread for foreground paths
    // (bootstrap, reloadComplicationsIfNeeded). For background task paths (process()),
    // setTaskCompletedWithSnapshot() must be called INSIDE DispatchQueue.main.async
    // after reloadTimeline() — otherwise watchOS suspends the extension before ClockKit
    // receives the reload request.
}
