// LoopFollow
// LiveActivityManager.swift

// swiftformat:disable indent
#if !targetEnvironment(macCatalyst)

@preconcurrency import ActivityKit
import Foundation
import os
import UIKit
import UserNotifications

// Live Activity manager for LoopFollow.

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundAudioFailed),
            name: .backgroundAudioFailed,
            object: nil,
        )
        startPushToStartTokenObservation()
        startActivityUpdatesObservation()
    }

    /// Observes the type-level push-to-start token (iOS 17.2+) and persists it.
    /// The token survives app relaunches but is reissued by iOS periodically or when
    /// the user toggles LA permissions — each new delivery overwrites the stored value.
    private func startPushToStartTokenObservation() {
        if #available(iOS 17.2, *) {
            pushToStartObservationTask?.cancel()
            pushToStartObservationTask = Task {
                for await tokenData in Activity<GlucoseLiveActivityAttributes>.pushToStartTokenUpdates {
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    let previousTail = Storage.shared.laPushToStartToken.value.isEmpty
                        ? "nil"
                        : String(Storage.shared.laPushToStartToken.value.suffix(8))
                    let tail = String(token.suffix(8))
                    Storage.shared.laPushToStartToken.value = token
                    LogManager.shared.log(
                        category: .general,
                        message: "[LA] push-to-start token received token=…\(tail) (prev=…\(previousTail))"
                    )
                }
            }
        }
    }

    /// Observes new Activity creations (iOS 16.2+). When an activity is started
    /// by push-to-start (iOS 17.2+), the app discovers it through this stream and
    /// adopts it via the same bind/update path as an app-initiated start.
    private func startActivityUpdatesObservation() {
        if #available(iOS 16.2, *) {
            activityUpdatesObservationTask?.cancel()
            activityUpdatesObservationTask = Task { [weak self] in
                for await activity in Activity<GlucoseLiveActivityAttributes>.activityUpdates {
                    await MainActor.run {
                        self?.adoptPushToStartActivity(activity)
                    }
                }
            }
        }
    }

    @MainActor
    private func adoptPushToStartActivity(_ activity: Activity<GlucoseLiveActivityAttributes>) {
        // Skip if it's the activity we already track (app-initiated path binds it directly).
        if current?.id == activity.id { return }
        // If we already have a current activity and this is a different one, it's likely
        // the new push-to-start LA replacing an old one. End the old, then bind the new.
        if let old = current, old.id != activity.id {
            LogManager.shared.log(
                category: .general,
                message: "[LA] activityUpdates: replacing old=\(old.id) with new=\(activity.id)"
            )
            let oldActivity = old
            Task {
                await oldActivity.end(nil, dismissalPolicy: .immediate)
            }
        } else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] activityUpdates: adopting new activity id=\(activity.id)"
            )
        }
        // Fresh deadline — push-to-start-initiated LAs reset the 8-hour clock.
        Storage.shared.laRenewBy.value = Date().timeIntervalSince1970 + LiveActivityManager.renewalThreshold
        Storage.shared.laRenewalFailed.value = false
        cancelRenewalFailedNotification()
        dismissedByUser = false
        bind(to: activity, logReason: "push-to-start-adopt")
    }

    /// Fires before the app loses focus (lock screen, home button, etc.).
    /// Cancels any pending debounced refresh and pushes the latest snapshot
    /// directly to the Live Activity while the app is still foreground-active,
    /// ensuring the LA is up to date the moment the lock screen appears.
    @objc private func handleWillResignActive() {
        guard Storage.shared.laEnabled.value, let activity = current else { return }

        refreshWorkItem?.cancel()
        refreshWorkItem = nil

        let provider = StorageCurrentGlucoseStateProvider()
        guard let snapshot = GlucoseSnapshotBuilder.build(from: provider) else { return }

        LAAppGroupSettings.setThresholds(
            lowMgdl: Storage.shared.lowLine.value,
            highMgdl: Storage.shared.highLine.value,
        )
        GlucoseSnapshotStore.shared.save(snapshot)

        seq += 1
        let nextSeq = seq
        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: snapshot,
            seq: nextSeq,
            reason: "resign-active",
            producedAt: Date(),
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date(timeIntervalSince1970: Storage.shared.laRenewBy.value),
            relevanceScore: 100.0,
        )

        Task {
            // Direct ActivityKit update — app is still active at this point.
            await activity.update(content)
            LogManager.shared.log(category: .general, message: "[LA] resign-active flush sent seq=\(nextSeq)", isDebug: true)
            // Also send APNs so the extension receives the latest token-based update.
            if let token = pushToken {
                await APNSClient.shared.sendLiveActivityUpdate(pushToken: token, state: state)
            }
        }
    }

    @objc private func handleDidBecomeActive() {
        guard Storage.shared.laEnabled.value else { return }
        let appState = UIApplication.shared.applicationState.rawValue
        let existing = Activity<GlucoseLiveActivityAttributes>.activities.count
        if pendingForegroundRestart {
            pendingForegroundRestart = false
            LogManager.shared.log(
                category: .general,
                message: "[LA] didBecomeActive: running deferred foreground restart (appState=\(appState), activities=\(existing))"
            )
            performForegroundRestart()
            return
        }
        LogManager.shared.log(category: .general, message: "[LA] didBecomeActive: startFromCurrentState (appState=\(appState), activities=\(existing), current=\(current?.id ?? "nil"), dismissedByUser=\(dismissedByUser))", isDebug: true)
        Task { @MainActor in
            self.startFromCurrentState()
        }
    }

    @objc private func handleForeground() {
        guard Storage.shared.laEnabled.value else { return }

        let renewalFailed = Storage.shared.laRenewalFailed.value
        let renewBy = Storage.shared.laRenewBy.value
        let now = Date().timeIntervalSince1970
        let overlayIsShowing = renewBy > 0 && now >= renewBy - LiveActivityManager.renewalWarning
        let appState = UIApplication.shared.applicationState.rawValue
        let existing = Activity<GlucoseLiveActivityAttributes>.activities.count

        LogManager.shared.log(
            category: .general,
            message: "[LA] foreground: appState=\(appState), activities=\(existing), renewalFailed=\(renewalFailed), overlayShowing=\(overlayIsShowing), current=\(current?.id ?? "nil"), dismissedByUser=\(dismissedByUser), renewBy=\(renewBy), now=\(now)"
        )

        guard renewalFailed || overlayIsShowing else {
            LogManager.shared.log(category: .general, message: "[LA] foreground: no action needed (not in renewal window)")
            return
        }

        // willEnterForegroundNotification fires before the scene reaches
        // foregroundActive — Activity.request() returns `visibility` during
        // this window. Defer the actual restart to didBecomeActive.
        pendingForegroundRestart = true
        LogManager.shared.log(
            category: .general,
            message: "[LA] foreground: scheduling restart on next didBecomeActive (renewalFailed=\(renewalFailed), overlayShowing=\(overlayIsShowing))"
        )
    }

    private func performForegroundRestart() {
        // Mark restart intent BEFORE clearing storage flags, so any late .dismissed
        // from the old activity is never misclassified as a user swipe.
        endingForRestart = true
        dismissedByUser = false

        // Stop any observers/tasks tied to the previous activity instance. In the
        // current=nil branch below, the old observer can otherwise deliver a late
        // .dismissed and poison dismissedByUser.
        updateTask?.cancel()
        updateTask = nil
        tokenObservationTask?.cancel()
        tokenObservationTask = nil
        stateObserverTask?.cancel()
        stateObserverTask = nil
        pushToken = nil

        // Clear renewal state so the new snapshot does not show the renewal overlay.
        Storage.shared.laRenewBy.value = 0
        Storage.shared.laRenewalFailed.value = false
        cancelRenewalFailedNotification()

        guard let activity = current else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] foreground restart: current=nil (old activity not bound locally), ending all existing LAs before restart"
            )
            current = nil

            Task {
                for activity in Activity<GlucoseLiveActivityAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                await MainActor.run {
                    self.dismissedByUser = false
                    self.startFromCurrentState(cleanupOrphans: false)
                    LogManager.shared.log(
                        category: .general,
                        message: "[LA] foreground restart: fresh LA started after ending unbound existing activity"
                    )
                }
            }
            return
        }

        current = nil

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run {
                self.dismissedByUser = false
                self.startFromCurrentState(cleanupOrphans: false)
                LogManager.shared.log(category: .general, message: "[LA] Live Activity restarted after foreground retry")
            }
        }
    }

    @objc private func handleBackgroundAudioFailed() {
        guard Storage.shared.laEnabled.value, current != nil else { return }
        // The background audio session has permanently failed — the app will lose its
        // background keep-alive. Immediately push the renewal overlay so the user sees
        // "Tap to update" on the lock screen and knows to foreground the app.
        LogManager.shared.log(category: .general, message: "[LA] background audio failed — forcing renewal overlay")
        Storage.shared.laRenewBy.value = Date().timeIntervalSince1970
        refreshFromCurrentState(reason: "audio-session-failed")
    }

    static let renewalThreshold: TimeInterval = 7.5 * 3600
    static let renewalWarning: TimeInterval = 30 * 60

    private(set) var current: Activity<GlucoseLiveActivityAttributes>?
    private var stateObserverTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var seq: Int = 0
    private var lastUpdateTime: Date?
    private var pushToken: String?
    private var tokenObservationTask: Task<Void, Never>?
    private var refreshWorkItem: DispatchWorkItem?
    /// Set when the user manually swipes away the LA. Blocks auto-restart until
    /// an explicit user action (Restart button, App Intent) clears it.
    /// In-memory only — resets to false on app relaunch, so a kill + relaunch
    /// starts fresh as expected.
    private var dismissedByUser = false
    /// Set to true immediately before we call activity.end() as part of a planned restart.
    /// Cleared after the restart completes. The state observer checks this flag so that
    /// a .dismissed delivery triggered by our own end() call is never misclassified as a
    /// user swipe — regardless of the order in which the MainActor executes the two writes.
    private var endingForRestart = false
    /// Set by handleForeground() when the renewal window has been detected.
    /// The actual end+restart is run from handleDidBecomeActive() because
    /// Activity.request() returns `visibility` during willEnterForeground.
    private var pendingForegroundRestart = false
    /// Observes `pushToStartTokenUpdates` (iOS 17.2+) and persists the token.
    /// Long-lived — started once at init and never cancelled.
    private var pushToStartObservationTask: Task<Void, Never>?
    /// Observes `Activity<>.activityUpdates` (iOS 16.2+) so activities started
    /// out-of-band (push-to-start) are adopted automatically.
    private var activityUpdatesObservationTask: Task<Void, Never>?
    /// Base backoff after a 429 for push-to-start; doubled on each subsequent 429,
    /// capped at `pushToStartMaxBackoff`. Reset to zero after a successful send.
    private static let pushToStartBaseBackoff: TimeInterval = 300 // 5 min
    private static let pushToStartMaxBackoff: TimeInterval = 3600 // 60 min

    // MARK: - Public API

    func startIfNeeded() {
        let authorized = ActivityAuthorizationInfo().areActivitiesEnabled
        let existingCount = Activity<GlucoseLiveActivityAttributes>.activities.count
        LogManager.shared.log(
            category: .general,
            message: "[LA] startIfNeeded: authorized=\(authorized), activities=\(existingCount), current=\(current?.id ?? "nil"), dismissedByUser=\(dismissedByUser), laEnabled=\(Storage.shared.laEnabled.value)",
            isDebug: true
        )
        guard authorized else {
            LogManager.shared.log(category: .general, message: "Live Activity not authorized")
            return
        }

        if let existing = Activity<GlucoseLiveActivityAttributes>.activities.first {
            // Before reusing, check whether this activity needs a restart. This covers cold
            // starts (app was killed while the overlay was showing — willEnterForeground is
            // never sent, so handleForeground never runs) and any other path that lands here
            // without first going through handleForeground.
            let renewBy = Storage.shared.laRenewBy.value
            let now = Date().timeIntervalSince1970
            let staleDatePassed = existing.content.staleDate.map { $0 <= Date() } ?? false
            let inRenewalWindow = renewBy > 0 && now >= renewBy - LiveActivityManager.renewalWarning
            let needsRestart = Storage.shared.laRenewalFailed.value || inRenewalWindow || staleDatePassed

            if needsRestart {
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] existing activity is stale on startIfNeeded — ending and restarting (staleDatePassed=\(staleDatePassed), inRenewalWindow=\(inRenewalWindow))"
                )

                endingForRestart = true
                dismissedByUser = false

                Storage.shared.laRenewBy.value = 0
                Storage.shared.laRenewalFailed.value = false
                cancelRenewalFailedNotification()

                Task {
                    await existing.end(nil, dismissalPolicy: .immediate)
                    await MainActor.run { self.startIfNeeded() }
                }
                return
            }

            bind(to: existing, logReason: "reuse")
            Storage.shared.laRenewalFailed.value = false
            return
        }

        do {
            let attributes = GlucoseLiveActivityAttributes(title: "LoopFollow")

            // Prefer a freshly built snapshot so all extended fields are populated.
            // Fall back to the persisted store (covers cold-start with real data),
            // then to a zero seed (true first-ever launch with no data yet).
            let provider = StorageCurrentGlucoseStateProvider()
            let seedSnapshot = GlucoseSnapshotBuilder.build(from: provider)
                ?? GlucoseSnapshotStore.shared.load()
                ?? GlucoseSnapshot(
                    glucose: 0,
                    delta: 0,
                    trend: .unknown,
                    updatedAt: Date(),
                    iob: nil,
                    cob: nil,
                    projected: nil,
                    unit: .mgdl,
                    isNotLooping: false,
                )

            let initialState = GlucoseLiveActivityAttributes.ContentState(
                snapshot: seedSnapshot,
                seq: 0,
                reason: "start",
                producedAt: Date(),
            )

            let renewDeadline = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)
            let content = ActivityContent(state: initialState, staleDate: renewDeadline)
            let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)

            bind(to: activity, logReason: "start-new")
            Storage.shared.laRenewBy.value = renewDeadline.timeIntervalSince1970
            Storage.shared.laRenewalFailed.value = false
            LogManager.shared.log(category: .general, message: "Live Activity started id=\(activity.id)")
        } catch {
            let ns = error as NSError
            let scene = isAppVisibleForLiveActivityStart()
            LogManager.shared.log(
                category: .general,
                message: "Live Activity failed to start: \(error) domain=\(ns.domain) code=\(ns.code) — authorized=\(ActivityAuthorizationInfo().areActivitiesEnabled), sceneActive=\(scene), activities=\(Activity<GlucoseLiveActivityAttributes>.activities.count)"
            )
        }
    }

    /// Called from applicationWillTerminate. Ends the LA synchronously (blocking
    /// up to 3 s) so it clears from the lock screen before the process exits.
    /// Does not clear laEnabled — the user's preference is preserved for relaunch.
    func endOnTerminate() {
        guard let activity = current else { return }
        // Flag the end as system-initiated so the state observer does not
        // classify the resulting `.dismissed` as a user swipe (laRenewBy is
        // cleared below, which would otherwise make pastDeadline=false).
        endingForRestart = true
        current = nil
        Storage.shared.laRenewBy.value = 0
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await activity.end(nil, dismissalPolicy: .immediate)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 3)
        LogManager.shared.log(category: .general, message: "[LA] ended on app terminate")
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
                    isNotLooping: false,
                ),
                seq: seq,
                reason: "end",
                producedAt: Date(),
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

    /// Ends all running Live Activities and starts a fresh one from the current state.
    /// Intended for the "Restart Live Activity" button and the AppIntent.
    @MainActor
    func forceRestart() {
        guard Storage.shared.laEnabled.value else { return }
        LogManager.shared.log(category: .general, message: "[LA] forceRestart called")
        // Mark as system-initiated so any residual `.dismissed` delivered from
        // the cancelled state observer stream cannot flip dismissedByUser=true
        // and spoil the freshly started LA.
        endingForRestart = true
        dismissedByUser = false
        Storage.shared.laRenewBy.value = 0
        Storage.shared.laRenewalFailed.value = false
        cancelRenewalFailedNotification()
        current = nil
        updateTask?.cancel(); updateTask = nil
        tokenObservationTask?.cancel(); tokenObservationTask = nil
        stateObserverTask?.cancel(); stateObserverTask = nil
        pushToken = nil
        Task {
            for activity in Activity<GlucoseLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            await MainActor.run {
                self.startFromCurrentState(cleanupOrphans: false)
                LogManager.shared.log(category: .general, message: "[LA] forceRestart: Live Activity restarted")
            }
        }
    }

    func startFromCurrentState(cleanupOrphans: Bool = false) {
        guard Storage.shared.laEnabled.value, !dismissedByUser else { return }

        if cleanupOrphans {
            endOrphanedActivities()
        }

        let provider = StorageCurrentGlucoseStateProvider()
        if let snapshot = GlucoseSnapshotBuilder.build(from: provider) {
            LAAppGroupSettings.setThresholds(
                lowMgdl: Storage.shared.lowLine.value,
                highMgdl: Storage.shared.highLine.value,
            )
            LAAppGroupSettings.setDisplayName(
                Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "LoopFollow",
                show: Storage.shared.showDisplayName.value
            )
            GlucoseSnapshotStore.shared.save(snapshot)
        }
        startIfNeeded()
    }

    func refreshFromCurrentState(reason: String) {
        // No LA guard here — Watch and store must update regardless of LA state.
        // LA-specific gating (laEnabled, dismissedByUser) is applied inside performRefresh.
        refreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performRefresh(reason: reason)
        }
        refreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0, execute: workItem)
    }

    // MARK: - Renewal

    /// Requests a fresh Live Activity to replace the current one when the renewal
    /// deadline has passed, working around Apple's 8-hour maximum LA lifetime.
    /// Returns true if a foreground restart was performed (caller returns early).
    private func renewIfNeeded(snapshot: GlucoseSnapshot) -> Bool {
        guard let oldActivity = current else { return false }

        let renewBy = Storage.shared.laRenewBy.value
        guard renewBy > 0, Date().timeIntervalSince1970 >= renewBy else { return false }

        let overdueBy = Date().timeIntervalSince1970 - renewBy
        return attemptLARestart(
            snapshot: snapshot,
            oldActivity: oldActivity,
            logReason: "renew",
            ageSeconds: overdueBy
        )
    }

    /// Unified restart path. Shared by deadline-based renewal so it takes the
    /// same foreground / background / push-to-start / mark-failed decisions.
    ///
    /// The new LA is requested FIRST — the old one is only ended if that
    /// succeeds, so the user keeps live data if `Activity.request()` throws.
    /// Returns true if a foreground restart was performed (caller returns
    /// early). Background paths return false even on successful push-to-start
    /// dispatch — their async handlers update state as results come in.
    private func attemptLARestart(
        snapshot: GlucoseSnapshot,
        oldActivity: Activity<GlucoseLiveActivityAttributes>,
        logReason: String,
        ageSeconds: TimeInterval
    ) -> Bool {
        // Activity.request() requires a foregroundActive scene — from the background
        // it always fails with `visibility`. Try push-to-start instead (iOS 17.2+);
        // fall back to marking renewal failed and waiting for the user to foreground
        // the app if push-to-start isn't available or doesn't succeed.
        guard isAppVisibleForLiveActivityStart() else {
            if attemptPushToStartIfEligible(snapshot: snapshot, overdueBy: ageSeconds, oldActivity: oldActivity) {
                return false
            }
            markRenewalFailedFromBackground(overdueBy: ageSeconds)
            return false
        }

        LogManager.shared.log(
            category: .general,
            message: "[LA] restart (\(logReason)) age=\(Int(ageSeconds))s, requesting new LA"
        )

        let renewDeadline = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)
        let attributes = GlucoseLiveActivityAttributes(title: "LoopFollow")

        // showRenewalOverlay: false — the new LA has a fresh deadline so no overlay
        // is needed from the first frame. The deadline is passed as staleDate below,
        // not written to Storage yet; Storage is only updated after Activity.request
        // succeeds so a crash between the two can't leave a stuck future deadline.
        let freshSnapshot = snapshot.withRenewalOverlay(false)

        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: freshSnapshot,
            seq: seq,
            reason: logReason,
            producedAt: Date(),
        )
        let content = ActivityContent(state: state, staleDate: renewDeadline)

        do {
            let newActivity = try Activity.request(attributes: attributes, content: content, pushType: .token)

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

            Storage.shared.laRenewBy.value = renewDeadline.timeIntervalSince1970
            bind(to: newActivity, logReason: logReason)
            Storage.shared.laRenewalFailed.value = false
            cancelRenewalFailedNotification()
            GlucoseSnapshotStore.shared.save(freshSnapshot)
            LogManager.shared.log(
                category: .general,
                message: "[LA] Live Activity restarted (\(logReason)) id=\(newActivity.id)"
            )
            return true
        } catch {
            let isFirstFailure = !Storage.shared.laRenewalFailed.value
            Storage.shared.laRenewalFailed.value = true
            let ns = error as NSError
            LogManager.shared.log(
                category: .general,
                message: "[LA] restart (\(logReason)) failed, keeping existing LA: \(error) domain=\(ns.domain) code=\(ns.code) — authorized=\(ActivityAuthorizationInfo().areActivitiesEnabled), activities=\(Activity<GlucoseLiveActivityAttributes>.activities.count)"
            )
            if isFirstFailure {
                scheduleRenewalFailedNotification()
            }
            return false
        }
    }

    /// Attempts to kick off a fresh LA via APNs push-to-start (iOS 17.2+) when the
    /// app is not foregroundActive and the renewal deadline has passed.
    ///
    /// Returns true if an APNs request was actually dispatched. When true, the
    /// async result handler updates backoff/renewal state. When false, the caller
    /// falls back to `markRenewalFailedFromBackground`.
    ///
    /// Rate-limited: the stored backoff gates subsequent attempts. On iOS <17.2
    /// no token is ever stored, so this path simply returns false.
    private func attemptPushToStartIfEligible(
        snapshot: GlucoseSnapshot,
        overdueBy: TimeInterval,
        oldActivity _: Activity<GlucoseLiveActivityAttributes>
    ) -> Bool {
        let token = Storage.shared.laPushToStartToken.value
        guard !token.isEmpty else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start unavailable (no token — iOS <17.2 or not yet issued)"
            )
            return false
        }

        let now = Date().timeIntervalSince1970
        let lastAt = Storage.shared.laLastPushToStartAt.value
        let backoff = Storage.shared.laPushToStartBackoff.value
        if lastAt > 0, now < lastAt + backoff {
            let wait = Int(lastAt + backoff - now)
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start rate-limited: next allowed in \(wait)s (backoff=\(Int(backoff))s)"
            )
            return false
        }

        // Record attempt time up-front so two refresh ticks can't double-fire.
        Storage.shared.laLastPushToStartAt.value = now

        seq += 1
        let nextSeq = seq
        let freshSnapshot = snapshot.withRenewalOverlay(false)
        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: freshSnapshot,
            seq: nextSeq,
            reason: "push-to-start",
            producedAt: Date(),
        )
        let staleDate = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)

        let tail = String(token.suffix(8))
        LogManager.shared.log(
            category: .general,
            message: "[LA] push-to-start firing overdueBy=\(Int(overdueBy))s token=…\(tail) seq=\(nextSeq)"
        )

        Task { [weak self] in
            let result = await APNSClient.shared.sendLiveActivityStart(
                pushToStartToken: token,
                attributesTitle: "LoopFollow",
                state: state,
                staleDate: staleDate,
            )
            await MainActor.run {
                self?.handlePushToStartResult(result, overdueBy: overdueBy)
            }
        }
        return true
    }

    @MainActor
    private func handlePushToStartResult(
        _ result: APNSClient.PushToStartResult,
        overdueBy: TimeInterval
    ) {
        switch result {
        case .success:
            // Adoption of the new LA runs via `activityUpdates` observation, which
            // ends the old activity, resets the renewal deadline and clears
            // `laRenewalFailed`. Apply base backoff so refresh ticks between now
            // and adoption don't re-fire push-to-start.
            Storage.shared.laPushToStartBackoff.value = LiveActivityManager.pushToStartBaseBackoff
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start succeeded — awaiting activityUpdates to adopt new LA"
            )
        case .rateLimited:
            let currentBackoff = Storage.shared.laPushToStartBackoff.value
            let next = min(
                LiveActivityManager.pushToStartMaxBackoff,
                max(LiveActivityManager.pushToStartBaseBackoff, currentBackoff * 2)
            )
            Storage.shared.laPushToStartBackoff.value = next
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start 429 — backoff raised to \(Int(next))s"
            )
            markRenewalFailedFromBackground(overdueBy: overdueBy)
        case .tokenInvalid:
            // Clear the stored token so the next `pushToStartTokenUpdates`
            // delivery can overwrite it. Reset backoff — no point holding off
            // while we wait for iOS to reissue.
            Storage.shared.laPushToStartToken.value = ""
            Storage.shared.laPushToStartBackoff.value = 0
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start token invalid — cleared, awaiting new token"
            )
            markRenewalFailedFromBackground(overdueBy: overdueBy)
        case .failed:
            let currentBackoff = Storage.shared.laPushToStartBackoff.value
            if currentBackoff < LiveActivityManager.pushToStartBaseBackoff {
                Storage.shared.laPushToStartBackoff.value = LiveActivityManager.pushToStartBaseBackoff
            }
            markRenewalFailedFromBackground(overdueBy: overdueBy)
        }
    }

    /// Background renewal couldn't restart the LA (not visible, and push-to-start
    /// unavailable or rate-limited). Mark the state so the renewal overlay shows
    /// on the lock screen, and post a local notification on the first failure so
    /// the user knows to foreground the app.
    private func markRenewalFailedFromBackground(overdueBy: TimeInterval) {
        let isFirstFailure = !Storage.shared.laRenewalFailed.value
        Storage.shared.laRenewalFailed.value = true
        LogManager.shared.log(
            category: .general,
            message: "[LA] renewal deadline passed by \(Int(overdueBy))s — app not visible, push-to-start unavailable, renewal marked failed"
        )
        if isFirstFailure {
            scheduleRenewalFailedNotification()
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
        // Capture dedup result BEFORE saving so the store comparison is valid.
        let snapshotUnchanged = GlucoseSnapshotStore.shared.load() == snapshot

        // Store + Watch: always update, independent of LA state.
        LAAppGroupSettings.setThresholds(
            lowMgdl: Storage.shared.lowLine.value,
            highMgdl: Storage.shared.highLine.value,
        )
        GlucoseSnapshotStore.shared.save(snapshot)
        // WatchConnectivityManager.shared.send(snapshot: snapshot)

        // LA update: gated on LA being active, snapshot having changed, and activities enabled.
        if !Storage.shared.laEnabled.value {
            LogManager.shared.log(category: .general, message: "[LA] refresh: LA update skipped — laEnabled=false reason=\(reason)", isDebug: true)
            return
        }
        if dismissedByUser {
            LogManager.shared.log(category: .general, message: "[LA] refresh: LA update skipped — dismissedByUser=true reason=\(reason)")
            return
        }
        guard !snapshotUnchanged || forceRefreshNeeded else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            LogManager.shared.log(category: .general, message: "[LA] refresh: LA update skipped — areActivitiesEnabled=false reason=\(reason)")
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
            producedAt: Date(),
        )

        updateTask = Task { [weak self] in
            guard let self else { return }

            if activity.activityState == .ended || activity.activityState == .dismissed {
                if current?.id == activityID { current = nil }
                return
            }

            let content = ActivityContent(
                state: state,
                staleDate: Date(timeIntervalSince1970: Storage.shared.laRenewBy.value),
                relevanceScore: 100.0,
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
            } else {
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] update seq=\(nextSeq) — app backgrounded, direct ActivityKit update skipped, relying on APNs",
                    isDebug: true
                )
            }

            if Task.isCancelled { return }

            guard current?.id == activityID else {
                LogManager.shared.log(category: .general, message: "Live Activity update — activity ID mismatch, discarding")
                return
            }

            lastUpdateTime = Date()
            LogManager.shared.log(category: .general, message: "[LA] updated id=\(activityID) seq=\(nextSeq) reason=\(reason)", isDebug: true)

            if let token = pushToken {
                await APNSClient.shared.sendLiveActivityUpdate(pushToken: token, state: state)
            } else {
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] update seq=\(nextSeq) reason=\(reason) — no push token yet, APNs skipped"
                )
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
        let wasEndingForRestart = endingForRestart
        dismissedByUser = false
        endingForRestart = false
        attachStateObserver(to: activity)
        LogManager.shared.log(
            category: .general,
            message: "Live Activity bound id=\(activity.id) state=\(activity.activityState) (\(logReason)) — endingForRestart cleared (was \(wasEndingForRestart))",
            isDebug: true
        )
        observePushToken(for: activity)
    }

    private func observePushToken(for activity: Activity<GlucoseLiveActivityAttributes>) {
        tokenObservationTask?.cancel()
        let activityID = activity.id
        tokenObservationTask = Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                let previousTail = self.pushToken.map { String($0.suffix(8)) } ?? "nil"
                let tail = String(token.suffix(8))
                self.pushToken = token
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] push token received id=\(activityID) token=…\(tail) (prev=…\(previousTail))"
                )
            }
        }
    }

    func handleExpiredToken() {
        let existing = Activity<GlucoseLiveActivityAttributes>.activities.count
        LogManager.shared.log(
            category: .general,
            message: "[LA] handleExpiredToken: current=\(current?.id ?? "nil"), activities=\(existing), dismissedByUser=\(dismissedByUser) — marking endingForRestart and ending"
        )
        // Mark as system-initiated so the `.dismissed` delivered by end()
        // is not classified as a user swipe — that would set dismissedByUser=true
        // and block the auto-restart promised by the comment below.
        endingForRestart = true
        end()
        // Activity will restart on next BG refresh via refreshFromCurrentState()
    }

    // MARK: - Renewal Notifications

    private static let renewalNotificationID = "\(Bundle.main.bundleIdentifier ?? "loopfollow").la.renewal.failed"

    private func scheduleRenewalFailedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Live Activity Expiring"
        content.body = "Live Activity will expire soon. Open LoopFollow to restart."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: LiveActivityManager.renewalNotificationID,
            content: content,
            trigger: trigger,
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                LogManager.shared.log(category: .general, message: "[LA] failed to schedule renewal notification: \(error)")
            }
        }
        LogManager.shared.log(category: .general, message: "[LA] renewal failed notification scheduled")
    }

    private func cancelRenewalFailedNotification() {
        let id = LiveActivityManager.renewalNotificationID
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }

    private func attachStateObserver(to activity: Activity<GlucoseLiveActivityAttributes>) {
        stateObserverTask?.cancel()
        stateObserverTask = Task {
            for await state in activity.activityStateUpdates {
                LogManager.shared.log(category: .general, message: "Live Activity state id=\(activity.id) -> \(state)", isDebug: true)
                if state == .ended || state == .dismissed {
                    if current?.id == activity.id {
                        current = nil
                        // Do NOT clear laRenewBy here. Preserving it means handleForeground()
                        // can detect the renewal window on the next foreground event and restart
                        // automatically — whether the LA ended normally (.ended) or was
                        // system-dismissed (.dismissed). laRenewBy is only set to 0 when:
                        //   • the user explicitly swipes (below) — renewal intent cancelled
                        //   • a new LA starts (startIfNeeded writes the new deadline)
                        //   • handleForeground() clears it synchronously before restarting
                        //   • the user disables LA or calls forceRestart
                        LogManager.shared.log(category: .general, message: "[LA] activity cleared id=\(activity.id) state=\(state)", isDebug: true)
                    }
                    if state == .dismissed {
                        // Three possible sources of .dismissed — only the third blocks restart:
                        //
                        // (a) endingForRestart: our own end() during a planned restart.
                        //     Must be checked first: handleForeground() clears laRenewalFailed
                        //     and laRenewBy synchronously before calling end(), so those flags
                        //     would read as "no problem" even though we initiated the dismissal.
                        //
                        // (b) iOS system force-dismiss: either laRenewalFailed is set (our 8-hour
                        //     renewal logic marked it) or the renewal deadline has already passed
                        //     (laRenewBy > 0 && now >= laRenewBy). In both cases iOS acted, not
                        //     the user. laRenewBy is preserved so handleForeground() restarts on
                        //     the next foreground.
                        //
                        // (c) User decision: the user explicitly swiped the LA away. Block
                        //     auto-restart until forceRestart() is called. Clear laRenewBy so
                        //     handleForeground() does NOT re-enter the renewal path on the next
                        //     foreground — the renewal intent is cancelled by the user's choice.
                        let now = Date().timeIntervalSince1970
                        let renewBy = Storage.shared.laRenewBy.value
                        let renewalFailed = Storage.shared.laRenewalFailed.value
                        let pastDeadline = renewBy > 0 && now >= renewBy
                        LogManager.shared.log(category: .general, message: "[LA] .dismissed: endingForRestart=\(endingForRestart), renewalFailed=\(renewalFailed), pastDeadline=\(pastDeadline), renewBy=\(renewBy), now=\(now)")
                        if endingForRestart {
                            // (a) Our own restart — do nothing, Task handles the rest.
                            LogManager.shared.log(category: .general, message: "[LA] dismissed by self (endingForRestart) — restart in-flight, no action")
                        } else if renewalFailed || pastDeadline {
                            // (b) iOS system force-dismiss — allow auto-restart on next foreground.
                            LogManager.shared.log(category: .general, message: "[LA] dismissed by iOS (renewalFailed=\(renewalFailed), pastDeadline=\(pastDeadline)) — auto-restart on next foreground")
                        } else {
                            // (c) User decision — cancel renewal intent, block auto-restart.
                            dismissedByUser = true
                            Storage.shared.laRenewBy.value = 0
                            LogManager.shared.log(category: .general, message: "[LA] dismissed by USER (renewBy=\(renewBy), now=\(now)) — laRenewBy cleared, auto-restart BLOCKED until forceRestart")
                        }
                    }
                }
            }
        }
    }
}

#endif

extension Notification.Name {
    /// Posted when the user taps the Live Activity or Dynamic Island.
    /// Observers navigate to the Home or Snoozer tab as appropriate.
    static let liveActivityDidForeground = Notification.Name("liveActivityDidForeground")
}
