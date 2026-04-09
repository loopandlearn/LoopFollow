// LoopFollow
// WatchSessionReceiver.swift

import ClockKit
import Foundation
import os.log
import WatchConnectivity
import WatchKit

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

    /// In-memory cache of the last received snapshot. Used by WatchComplicationProvider as a
    /// fallback when GlucoseSnapshotStore.load() returns nil (e.g. file write race or first launch).
    /// Always reflects the most recently delivered snapshot regardless of file-store state.
    private(set) var lastSnapshot: GlucoseSnapshot?

    /// Cache of CLKComplication objects keyed by "<identifier>-<family.rawValue>".
    /// Populated when ClockKit calls getCurrentTimelineEntry (complication is on an active face)
    /// or when activeComplications is non-nil. Used as a fallback when activeComplications
    /// returns nil/empty during background execution — a known watchOS 9+ limitation.
    ///
    /// Access must be serialized on the main thread. ClockKit callbacks are main-thread,
    /// and reloadComplicationsOnMainThread() is only called from main.
    private var cachedComplications: [String: CLKComplication] = [:]

    /// Called by WatchComplicationProvider whenever ClockKit passes a CLKComplication to us.
    /// Must be called on the main thread (ClockKit callbacks are main-thread).
    func cacheComplication(_ complication: CLKComplication) {
        dispatchPrecondition(condition: .onQueue(.main))
        let key = "\(complication.identifier)-\(complication.family.rawValue)"
        cachedComplications[key] = complication
    }

    // MARK: - Init

    override private init() {
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
            // GlucoseSnapshot has a custom decoder that reads `updatedAt` as a
            // Double, so no JSONDecoder date strategy is required.
            let decoder = JSONDecoder()
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
        _: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        process(payload: message, source: "sendMessage")
    }

    /// Handles queued background delivery (transferUserInfo path).
    func session(
        _: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        process(payload: userInfo, source: "userInfo")
    }

    func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        process(payload: applicationContext, source: "applicationContext")
    }

    // MARK: - Private

    private func process(payload: [String: Any], source: String) {
        guard let data = payload["snapshot"] as? Data else {
            os_log("WatchSessionReceiver: %{public}@ — no snapshot key", log: watchLog, type: .debug, source)
            return
        }
        do {
            // GlucoseSnapshot has a custom decoder that reads `updatedAt` as a
            // Double, so no JSONDecoder date strategy is required.
            let decoder = JSONDecoder()
            let snapshot = try decoder.decode(GlucoseSnapshot.self, from: data)
            // Cache in memory immediately — complication provider can use this as a
            // fallback if the App Group file store hasn't flushed yet.
            lastSnapshot = snapshot
            os_log("WatchSessionReceiver: %{public}@ snapshot decoded g=%d, saving", log: watchLog, type: .debug, source, Int(snapshot.glucose))
            GlucoseSnapshotStore.shared.save(snapshot) { [weak self] in
                os_log("WatchSessionReceiver: %{public}@ snapshot saved, reloading complications", log: watchLog, type: .debug, source)
                // ACK to iPhone so it can detect missed deliveries.
                self?.sendAck(for: snapshot)
                // Capture and clear the pending task before dispatching to main,
                // then complete it AFTER reloadTimeline() so watchOS doesn't suspend
                // the extension before ClockKit processes the reload request.
                let task = self?.pendingConnectivityTask
                self?.pendingConnectivityTask = nil
                DispatchQueue.main.async { [weak self] in
                    self?.reloadComplicationsOnMainThread()
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

    /// Reloads all known complications. May be called from any thread.
    func reloadComplications() {
        DispatchQueue.main.async { self.reloadComplicationsOnMainThread() }
    }

    /// Must be called on the main thread. Used directly when already on main (e.g., from process()).
    private func reloadComplicationsOnMainThread() {
        let server = CLKComplicationServer.sharedInstance()

        let complications: [CLKComplication]
        if let active = server.activeComplications, !active.isEmpty {
            // Update the cache whenever activeComplications is non-nil.
            active.forEach { self.cacheComplication($0) }
            complications = active
            os_log("WatchSessionReceiver: reloading %d active complication(s)", log: watchLog, type: .info, complications.count)
        } else if !cachedComplications.isEmpty {
            // activeComplications is nil/empty — common during background execution on watchOS 9+.
            // Use the cached CLKComplication objects from the last call where activeComplications was valid.
            complications = Array(cachedComplications.values)
            os_log("WatchSessionReceiver: activeComplications nil/empty — using %d cached complication(s)", log: watchLog, type: .info, complications.count)
        } else {
            os_log("WatchSessionReceiver: no active or cached complications — reloadTimeline skipped", log: watchLog, type: .error)
            return
        }

        for complication in complications {
            server.reloadTimeline(for: complication)
        }
        os_log("WatchSessionReceiver: reloadTimeline called for %d complication(s)", log: watchLog, type: .info, complications.count)
    }

    // NOTE: reloadComplications() is safe to call from any thread for foreground paths
    // (bootstrap, reloadComplicationsIfNeeded). For background task paths (process()),
    // setTaskCompletedWithSnapshot() must be called INSIDE DispatchQueue.main.async
    // after reloadTimeline() — otherwise watchOS suspends the extension before ClockKit
    // receives the reload request.
}
