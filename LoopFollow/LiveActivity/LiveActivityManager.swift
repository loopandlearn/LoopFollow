// LoopFollow
// LiveActivityManager.swift

@preconcurrency import ActivityKit
import Foundation
import os
import UIKit

/// Live Activity manager for LoopFollow.

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func handleForeground() {
        LogManager.shared.log(category: .general, message: "[LA] foreground notification received, laRenewalFailed=\(Storage.shared.laRenewalFailed.value)")
        guard Storage.shared.laRenewalFailed.value else { return }

        // Renewal previously failed — end the stale LA and start a fresh one.
        // We cannot call startIfNeeded() here: it finds the existing activity in
        // Activity.activities and reuses it rather than replacing it.
        LogManager.shared.log(category: .general, message: "[LA] ending stale LA and restarting after renewal failure")
        // Clear the expired deadline synchronously so any snapshot built between now
        // and when the new LA is started computes showRenewalOverlay = false.
        Storage.shared.laRenewBy.value = 0
        if let activity = current {
            current = nil
            updateTask?.cancel()
            updateTask = nil
            tokenObservationTask?.cancel()
            tokenObservationTask = nil
            stateObserverTask?.cancel()
            stateObserverTask = nil
            pushToken = nil
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
                await MainActor.run {
                    self.startFromCurrentState()
                    LogManager.shared.log(category: .general, message: "[LA] Live Activity restarted after foreground retry")
                }
            }
        } else {
            startFromCurrentState()
        }
    }

    // TEST VALUES — restore both to production before merging:
    //   renewalThreshold = 7.5 * 3600
    //   renewalWarning   = 20 * 60
    static let renewalThreshold: TimeInterval = 20 * 60
    static let renewalWarning: TimeInterval = 5 * 60

    private(set) var current: Activity<GlucoseLiveActivityAttributes>?
    private var stateObserverTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var seq: Int = 0
    private var lastUpdateTime: Date?
    private var pushToken: String?
    private var tokenObservationTask: Task<Void, Never>?
    private var refreshWorkItem: DispatchWorkItem?

    // MARK: - Public API

    func startIfNeeded() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            LogManager.shared.log(category: .general, message: "Live Activity not authorized")
            return
        }

        if let existing = Activity<GlucoseLiveActivityAttributes>.activities.first {
            bind(to: existing, logReason: "reuse")
            Storage.shared.laRenewalFailed.value = false
            return
        }

        do {
            let attributes = GlucoseLiveActivityAttributes(title: "LoopFollow")

            let seedSnapshot = GlucoseSnapshotStore.shared.load() ?? GlucoseSnapshot(
                glucose: 0,
                delta: 0,
                trend: .unknown,
                updatedAt: Date(),
                iob: nil,
                cob: nil,
                projected: nil,
                unit: .mgdl,
                isNotLooping: false
            )

            let initialState = GlucoseLiveActivityAttributes.ContentState(
                snapshot: seedSnapshot,
                seq: 0,
                reason: "start",
                producedAt: Date()
            )

            let renewDeadline = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)
            let content = ActivityContent(state: initialState, staleDate: renewDeadline)
            let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)

            bind(to: activity, logReason: "start-new")
            Storage.shared.laRenewBy.value = renewDeadline.timeIntervalSince1970
            Storage.shared.laRenewalFailed.value = false
            LogManager.shared.log(category: .general, message: "Live Activity started id=\(activity.id)")
        } catch {
            LogManager.shared.log(category: .general, message: "Live Activity failed to start: \(error)")
        }
    }

    func end(dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        updateTask?.cancel()
        updateTask = nil

        guard let activity = current else { return }

        Task {
            let finalState = GlucoseLiveActivityAttributes.ContentState(
                snapshot: GlucoseSnapshotStore.shared.load() ?? GlucoseSnapshot(
                    glucose: 0,
                    delta: 0,
                    trend: .unknown,
                    updatedAt: Date(),
                    iob: nil,
                    cob: nil,
                    projected: nil,
                    unit: .mgdl,
                    isNotLooping: false
                ),
                seq: seq,
                reason: "end",
                producedAt: Date()
            )

            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: dismissalPolicy)

            LogManager.shared.log(category: .general, message: "Live Activity ended id=\(activity.id)", isDebug: true)

            if current?.id == activity.id {
                current = nil
                Storage.shared.laRenewBy.value = 0
            }
        }
    }

    func startFromCurrentState() {
        endOrphanedActivities()
        let provider = StorageCurrentGlucoseStateProvider()
        if let snapshot = GlucoseSnapshotBuilder.build(from: provider) {
            LAAppGroupSettings.setThresholds(
                lowMgdl: Storage.shared.lowLine.value,
                highMgdl: Storage.shared.highLine.value
            )
            GlucoseSnapshotStore.shared.save(snapshot)
        }
        startIfNeeded()
    }

    func refreshFromCurrentState(reason: String) {
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performRefresh(reason: reason)
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }

    // MARK: - Renewal

    /// Requests a fresh Live Activity to replace the current one when the renewal
    /// deadline has passed, working around Apple's 8-hour maximum LA lifetime.
    /// The new LA is requested FIRST — the old one is only ended if that succeeds,
    /// so the user keeps live data if Activity.request() throws.
    /// Returns true if renewal was performed (caller should return early).
    private func renewIfNeeded(snapshot: GlucoseSnapshot) -> Bool {
        guard let oldActivity = current else { return false }

        let renewBy = Storage.shared.laRenewBy.value
        guard renewBy > 0, Date().timeIntervalSince1970 >= renewBy else { return false }

        let overdueBy = Date().timeIntervalSince1970 - renewBy
        LogManager.shared.log(category: .general, message: "[LA] renewal deadline passed by \(Int(overdueBy))s, requesting new LA")

        let renewDeadline = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)
        let attributes = GlucoseLiveActivityAttributes(title: "LoopFollow")

        // Strip the overlay flag — the new LA has a fresh deadline so it should
        // open clean, without the warning visible from the first frame.
        let freshSnapshot = GlucoseSnapshot(
            glucose: snapshot.glucose,
            delta: snapshot.delta,
            trend: snapshot.trend,
            updatedAt: snapshot.updatedAt,
            iob: snapshot.iob,
            cob: snapshot.cob,
            projected: snapshot.projected,
            unit: snapshot.unit,
            isNotLooping: snapshot.isNotLooping,
            showRenewalOverlay: false
        )
        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: freshSnapshot,
            seq: seq,
            reason: "renew",
            producedAt: Date()
        )
        let content = ActivityContent(state: state, staleDate: renewDeadline)

        do {
            let newActivity = try Activity.request(attributes: attributes, content: content, pushType: .token)

            // New LA is live — now it's safe to remove the old card.
            Task {
                await oldActivity.end(nil, dismissalPolicy: .immediate)
            }

            updateTask?.cancel()
            updateTask = nil
            tokenObservationTask?.cancel()
            tokenObservationTask = nil
            stateObserverTask?.cancel()
            stateObserverTask = nil
            pushToken = nil

            bind(to: newActivity, logReason: "renew")
            Storage.shared.laRenewBy.value = renewDeadline.timeIntervalSince1970
            Storage.shared.laRenewalFailed.value = false
            // Update the store so the next duplicate check has the correct baseline.
            GlucoseSnapshotStore.shared.save(freshSnapshot)
            LogManager.shared.log(category: .general, message: "[LA] Live Activity renewed successfully id=\(newActivity.id)")
            return true
        } catch {
            Storage.shared.laRenewalFailed.value = true
            LogManager.shared.log(category: .general, message: "[LA] renewal failed, keeping existing LA: \(error)")
            return false
        }
    }

    private func performRefresh(reason: String) {
        let provider = StorageCurrentGlucoseStateProvider()
        guard let snapshot = GlucoseSnapshotBuilder.build(from: provider) else {
            return
        }
        LogManager.shared.log(category: .general, message: "[LA] refresh g=\(snapshot.glucose) reason=\(reason)", isDebug: true)
        let fingerprint =
            "g=\(snapshot.glucose) d=\(snapshot.delta) t=\(snapshot.trend.rawValue) " +
            "at=\(snapshot.updatedAt.timeIntervalSince1970) iob=\(snapshot.iob?.description ?? "nil") " +
            "cob=\(snapshot.cob?.description ?? "nil") proj=\(snapshot.projected?.description ?? "nil") u=\(snapshot.unit.rawValue)"
        LogManager.shared.log(category: .general, message: "[LA] snapshot \(fingerprint) reason=\(reason)", isDebug: true)

        // Check if the Live Activity is approaching Apple's 8-hour limit and renew if so.
        if renewIfNeeded(snapshot: snapshot) { return }

        if snapshot.showRenewalOverlay {
            LogManager.shared.log(category: .general, message: "[LA] sending update with renewal overlay visible")
        }

        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime ?? .distantPast)
        let forceRefreshNeeded = timeSinceLastUpdate >= 5 * 60
        if let previous = GlucoseSnapshotStore.shared.load(), previous == snapshot, !forceRefreshNeeded {
            return
        }
        LAAppGroupSettings.setThresholds(
            lowMgdl: Storage.shared.lowLine.value,
            highMgdl: Storage.shared.highLine.value
        )
        GlucoseSnapshotStore.shared.save(snapshot)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        if current == nil, let existing = Activity<GlucoseLiveActivityAttributes>.activities.first {
            bind(to: existing, logReason: "bind-existing")
        }
        if let _ = current {
            update(snapshot: snapshot, reason: reason)
            return
        }
        if isAppVisibleForLiveActivityStart() {
            startIfNeeded()
            if current != nil {
                update(snapshot: snapshot, reason: reason)
            }
        } else {
            LogManager.shared.log(category: .general, message: "LA start suppressed (not visible) reason=\(reason)", isDebug: true)
        }
    }

    private func isAppVisibleForLiveActivityStart() -> Bool {
        let scenes = UIApplication.shared.connectedScenes
        return scenes.contains { $0.activationState == .foregroundActive }
    }

    func update(snapshot: GlucoseSnapshot, reason: String) {
        if current == nil, let existing = Activity<GlucoseLiveActivityAttributes>.activities.first {
            bind(to: existing, logReason: "bind-existing")
        }

        guard let activity = current else { return }

        updateTask?.cancel()

        seq += 1
        let nextSeq = seq
        let activityID = activity.id

        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: snapshot,
            seq: nextSeq,
            reason: reason,
            producedAt: Date()
        )

        updateTask = Task { [weak self] in
            guard let self else { return }

            if activity.activityState == .ended || activity.activityState == .dismissed {
                if self.current?.id == activityID { self.current = nil }
                return
            }

            let content = ActivityContent(
                state: state,
                staleDate: Date(timeIntervalSince1970: Storage.shared.laRenewBy.value),
                relevanceScore: 100.0
            )

            if Task.isCancelled { return }

            // Dual-path update strategy:
            // - Foreground: direct ActivityKit update works reliably.
            // - Background: direct update silently fails due to the audio session
            //   limitation. APNs self-push is the only reliable delivery path.
            //   Both paths are attempted when applicable; APNs is the authoritative
            //   background mechanism.
            let isForeground = await MainActor.run {
                UIApplication.shared.applicationState == .active
            }

            if isForeground {
                await activity.update(content)
            }

            if Task.isCancelled { return }

            guard self.current?.id == activityID else {
                LogManager.shared.log(category: .general, message: "Live Activity update — activity ID mismatch, discarding")
                return
            }

            self.lastUpdateTime = Date()
            LogManager.shared.log(category: .general, message: "[LA] updated id=\(activityID) seq=\(nextSeq) reason=\(reason)", isDebug: true)

            if let token = self.pushToken {
                await APNSClient.shared.sendLiveActivityUpdate(pushToken: token, state: state)
            }
        }
    }

    // MARK: - Binding / Lifecycle

    /// Ends any Live Activities of this type that are not the one currently tracked.
    /// Called on app launch to clean up cards left behind by a previous crash.
    private func endOrphanedActivities() {
        for activity in Activity<GlucoseLiveActivityAttributes>.activities {
            guard activity.id != current?.id else { continue }
            let orphanID = activity.id
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
                LogManager.shared.log(category: .general, message: "Ended orphaned Live Activity id=\(orphanID)")
            }
        }
    }

    private func bind(to activity: Activity<GlucoseLiveActivityAttributes>, logReason: String) {
        if current?.id == activity.id { return }
        current = activity
        attachStateObserver(to: activity)
        LogManager.shared.log(category: .general, message: "Live Activity bound id=\(activity.id) (\(logReason))", isDebug: true)
        observePushToken(for: activity)
    }

    private func observePushToken(for activity: Activity<GlucoseLiveActivityAttributes>) {
        tokenObservationTask?.cancel()
        tokenObservationTask = Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                self.pushToken = token
                LogManager.shared.log(category: .general, message: "Live Activity push token received", isDebug: true)
            }
        }
    }

    func handleExpiredToken() {
        end()
        // Activity will restart on next BG refresh via refreshFromCurrentState()
    }

    private func attachStateObserver(to activity: Activity<GlucoseLiveActivityAttributes>) {
        stateObserverTask?.cancel()
        stateObserverTask = Task {
            for await state in activity.activityStateUpdates {
                LogManager.shared.log(category: .general, message: "Live Activity state id=\(activity.id) -> \(state)", isDebug: true)
                if state == .ended || state == .dismissed {
                    if current?.id == activity.id {
                        current = nil
                        LogManager.shared.log(category: .general, message: "Live Activity cleared id=\(activity.id)", isDebug: true)
                    }
                }
            }
        }
    }
}
