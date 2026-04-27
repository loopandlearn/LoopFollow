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
//
// iOS 17.2+:        every LA creation (initial start, renewal, forced
//                   restart) goes through APNs push-to-start. Updates
//                   ride the same APNs transport. One transport, one
//                   credential failure mode that surfaces in settings.
//
// iOS 16.6 – 17.1:  legacy Activity.request() for everything;
//                   renewal-failed notification when backgrounded.
//                   The entry-point `if #available(iOS 17.2, *)` checks
//                   isolate every iOS 17.2 code path, so the legacy
//                   helpers can be deleted in one commit when the
//                   deployment target reaches 17.2.

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

    // MARK: - Push-to-start observation (iOS 17.2+)

    /// Observes the type-level push-to-start token (iOS 17.2+) and persists it.
    /// The token survives app relaunches but is reissued by iOS periodically or when
    /// the user toggles LA permissions — each new delivery overwrites the stored value.
    private func startPushToStartTokenObservation() {
        if #available(iOS 17.2, *) {
            pushToStartObservationTask?.cancel()
            LogManager.shared.log(
                category: .general,
                message: "[LA] pushToStartTokenUpdates observation starting (iOS 17.2+)"
            )
            pushToStartObservationTask = Task {
                var deliveries = 0
                for await tokenData in Activity<GlucoseLiveActivityAttributes>.pushToStartTokenUpdates {
                    deliveries += 1
                    let token = tokenData.map { String(format: "%02x", $0) }.joined()
                    let previousTail = Storage.shared.laPushToStartToken.value.isEmpty
                        ? "nil"
                        : String(Storage.shared.laPushToStartToken.value.suffix(8))
                    let tail = String(token.suffix(8))
                    let changed = tail != previousTail
                    Storage.shared.laPushToStartToken.value = token
                    LogManager.shared.log(
                        category: .general,
                        message: "[LA] push-to-start token received #\(deliveries) token=…\(tail) (prev=…\(previousTail))\(changed ? " CHANGED" : " same")"
                    )
                }
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] pushToStartTokenUpdates stream ended after \(deliveries) deliveries — no further tokens will arrive"
                )
            }
        } else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] pushToStartTokenUpdates unavailable (iOS <17.2) — push-to-start will never fire"
            )
        }
    }

    /// Observes new Activity creations. When an activity is started by
    /// push-to-start (iOS 17.2+), the app discovers it through this stream and
    /// adopts it via the same bind/update path as an app-initiated start.
    private func startActivityUpdatesObservation() {
        activityUpdatesObservationTask?.cancel()
        LogManager.shared.log(
            category: .general,
            message: "[LA] activityUpdates observation starting"
        )
        activityUpdatesObservationTask = Task { [weak self] in
            var deliveries = 0
            for await activity in Activity<GlucoseLiveActivityAttributes>.activityUpdates {
                deliveries += 1
                let incomingID = activity.id
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] activityUpdates delivery #\(deliveries) id=\(incomingID) — dispatching to MainActor"
                )
                await MainActor.run {
                    self?.adoptPushToStartActivity(activity)
                }
            }
            LogManager.shared.log(
                category: .general,
                message: "[LA] activityUpdates stream ended after \(deliveries) deliveries — push-to-start adoption will no longer work until app relaunch"
            )
        }
    }

    @MainActor
    private func adoptPushToStartActivity(_ activity: Activity<GlucoseLiveActivityAttributes>) {
        // Skip if it's the activity we already track (app-initiated path binds it directly).
        if current?.id == activity.id {
            LogManager.shared.log(
                category: .general,
                message: "[LA] activityUpdates: ignoring own activity id=\(activity.id) (already current)"
            )
            return
        }

        let adoptDelay = lastPushToStartSuccessAt.map { Int(Date().timeIntervalSince($0)) }
        let delayDescription = adoptDelay.map { "\($0)s after last push-to-start success" } ?? "no prior push-to-start this session"
        let totalActivities = Activity<GlucoseLiveActivityAttributes>.activities.count
        let staleDate = activity.content.staleDate
        let staleDesc = staleDate.map { String(format: "%.0f", $0.timeIntervalSinceNow) + "s" } ?? "nil"
        let incomingSeq = activity.content.state.seq
        LogManager.shared.log(
            category: .general,
            message: "[LA] adopt: id=\(activity.id) seq=\(incomingSeq) staleIn=\(staleDesc) totalActivities=\(totalActivities) (\(delayDescription))"
        )
        lastPushToStartSuccessAt = nil
        pushToStartSendsWithoutAdoption = 0

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
                message: "[LA] activityUpdates: adopting new activity id=\(activity.id) (no prior current)"
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
        if skipNextDidBecomeActive {
            LogManager.shared.log(category: .general, message: "[LA] didBecomeActive: skipped (handleForeground owns restart)", isDebug: true)
            skipNextDidBecomeActive = false
            return
        }
        LogManager.shared.log(category: .general, message: "[LA] didBecomeActive: calling startFromCurrentState, dismissedByUser=\(dismissedByUser)", isDebug: true)
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
        let stuckSends = pushToStartSendsWithoutAdoption
        let pushToStartLooksStuck = stuckSends >= LiveActivityManager.pushToStartForceRestartThreshold

        LogManager.shared.log(
            category: .general,
            message: "[LA] foreground: renewalFailed=\(renewalFailed), overlayShowing=\(overlayIsShowing), current=\(current?.id ?? "nil"), dismissedByUser=\(dismissedByUser), renewBy=\(renewBy), now=\(now), pushToStartSendsWithoutAdoption=\(stuckSends)"
        )

        guard renewalFailed || overlayIsShowing || pushToStartLooksStuck else {
            LogManager.shared.log(category: .general, message: "[LA] foreground: no action needed (not in renewal window)")
            return
        }

        if pushToStartLooksStuck {
            // Reset the counter now so we don't re-trigger on every foreground
            // entry until the next round of silently-failed sends actually
            // builds up again. The restart itself ends the current LA and
            // starts a fresh one, which (per Apple's docs) should cause iOS to
            // emit a new pushToStartToken — the workaround for FB21158660.
            pushToStartSendsWithoutAdoption = 0
            LogManager.shared.log(
                category: .general,
                message: "[LA] foreground: push-to-start looks stuck (sendsWithoutAdoption=\(stuckSends) ≥ \(LiveActivityManager.pushToStartForceRestartThreshold)) — forcing local restart to nudge token rotation"
            )
        } else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] ending stale LA and restarting (renewalFailed=\(renewalFailed), overlayShowing=\(overlayIsShowing))"
            )
        }

        skipNextDidBecomeActive = true

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

    private func shouldRestartBecauseExtensionLooksStuck() -> Bool {
        guard Storage.shared.laEnabled.value else { return false }
        guard !dismissedByUser else { return false }

        guard let activity = current ?? Activity<GlucoseLiveActivityAttributes>.activities.first else {
            return false
        }

        let now = Date().timeIntervalSince1970
        let staleDatePassed = activity.content.staleDate.map { $0 <= Date() } ?? false
        if staleDatePassed {
            LogManager.shared.log(
                category: .general,
                message: "[LA] liveness check: staleDate already passed"
            )
            return true
        }

        let expectedSeq = activity.content.state.seq
        let seenSeq = LALivenessStore.lastExtensionSeq
        let lastSeenAt = LALivenessStore.lastExtensionSeenAt
        let lastProducedAt = LALivenessStore.lastExtensionProducedAt

        let extensionHasNeverCheckedIn = lastSeenAt <= 0
        let extensionLooksBehind = seenSeq < expectedSeq
        let noRecentExtensionTouch = extensionHasNeverCheckedIn || (now - lastSeenAt > LiveActivityManager.extensionLivenessGrace)

        LogManager.shared.log(
            category: .general,
            message: "[LA] liveness check: expectedSeq=\(expectedSeq), seenSeq=\(seenSeq), lastSeenAt=\(lastSeenAt), lastProducedAt=\(lastProducedAt), behind=\(extensionLooksBehind), noRecentTouch=\(noRecentExtensionTouch)",
            isDebug: true
        )

        // Conservative rule:
        // only suspect "stuck" if the extension is both behind AND has not checked in recently.
        return extensionLooksBehind && noRecentExtensionTouch
    }

    static let renewalThreshold: TimeInterval = 7.5 * 3600
    static let renewalWarning: TimeInterval = 30 * 60
    static let extensionLivenessGrace: TimeInterval = 15 * 60

    /// Base backoff after a 429 for push-to-start; doubled on each subsequent 429,
    /// capped at `pushToStartMaxBackoff`. Reset to base after a successful send.
    private static let pushToStartBaseBackoff: TimeInterval = 300 // 5 min
    private static let pushToStartMaxBackoff: TimeInterval = 3600 // 60 min
    /// When a successful APNs push-to-start does not result in an `activityUpdates`
    /// adoption, count those orphaned sends. After this threshold, the next
    /// foreground entry forces a local restart to nudge iOS to issue a new
    /// pushToStartToken — Apple FB21158660 workaround.
    private static let pushToStartForceRestartThreshold: Int = 2
    /// Polling timeout for the push-to-start token to arrive after a fresh install.
    /// `pushToStartTokenUpdates` typically delivers within a couple of seconds.
    private static let pushToStartTokenWaitTimeout: TimeInterval = 5
    private static let pushToStartTokenPollInterval: TimeInterval = 0.5

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
    /// Set by handleForeground() when it takes ownership of the restart sequence.
    /// Prevents handleDidBecomeActive() from racing with an in-flight end+restart.
    private var skipNextDidBecomeActive = false
    /// Observes `pushToStartTokenUpdates` (iOS 17.2+) and persists the token.
    /// Long-lived — started once at init and never cancelled.
    private var pushToStartObservationTask: Task<Void, Never>?
    /// Observes `Activity<>.activityUpdates` so activities started out-of-band
    /// (push-to-start) are adopted automatically.
    private var activityUpdatesObservationTask: Task<Void, Never>?
    /// Timestamp of the last successful push-to-start APNs dispatch. Used to log
    /// the delay until iOS delivers the new activity via `activityUpdates`. If
    /// adoption never happens, a growing gap here is the fingerprint.
    private var lastPushToStartSuccessAt: Date?
    /// Number of consecutive successful push-to-start APNs sends that have NOT
    /// been followed by an `activityUpdates` adoption. When this reaches
    /// `pushToStartForceRestartThreshold`, the next foreground entry forces a
    /// local restart even outside the renewal window — ending the existing LA
    /// and starting a fresh one is the only known way to nudge iOS to issue a
    /// new `pushToStartToken` when the current one has gone silent
    /// (Apple FB21158660).
    private var pushToStartSendsWithoutAdoption: Int = 0

    // MARK: - Public API

    @MainActor
    func startIfNeeded() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            LogManager.shared.log(category: .general, message: "Live Activity not authorized")
            return
        }

        if #available(iOS 17.2, *) {
            // iOS 17.2+ uses push-to-start for every creation path. If an
            // activity is already running and not stale we adopt/reuse it
            // (covers warm starts where the LA survived a relaunch); only
            // truly new starts dispatch APNs.
            if let existing = Activity<GlucoseLiveActivityAttributes>.activities.first {
                let renewBy = Storage.shared.laRenewBy.value
                let now = Date().timeIntervalSince1970
                let staleDatePassed = existing.content.staleDate.map { $0 <= Date() } ?? false
                let inRenewalWindow = renewBy > 0 && now >= renewBy - LiveActivityManager.renewalWarning
                let needsRestart = Storage.shared.laRenewalFailed.value || inRenewalWindow || staleDatePassed
                if !needsRestart {
                    bind(to: existing, logReason: "reuse")
                    Storage.shared.laRenewalFailed.value = false
                    return
                }
                LogManager.shared.log(
                    category: .general,
                    message: "[LA] existing activity is stale on startIfNeeded (iOS 17.2+) — push-to-start replace (staleDatePassed=\(staleDatePassed), inRenewalWindow=\(inRenewalWindow))"
                )
                attemptPushToStartCreate(reason: "user-start", oldActivity: existing)
                return
            }
            attemptPushToStartCreate(reason: "user-start", oldActivity: nil)
        } else {
            startIfNeededLegacy()
        }
    }

    /// Pre-17.2 path (iOS 16.6 – 17.1). Identical to dev's `startIfNeeded` —
    /// Activity.request() for everything. Removable when the deployment target
    /// reaches 17.2.
    @MainActor
    private func startIfNeededLegacy() {
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
                    await MainActor.run { self.startIfNeededLegacy() }
                }
                return
            }

            bind(to: existing, logReason: "reuse")
            Storage.shared.laRenewalFailed.value = false
            return
        }

        do {
            let attributes = GlucoseLiveActivityAttributes(title: "LoopFollow")

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
            LALivenessStore.clear()
            let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)

            bind(to: activity, logReason: "start-new")
            Storage.shared.laRenewBy.value = renewDeadline.timeIntervalSince1970
            Storage.shared.laRenewalFailed.value = false
            LogManager.shared.log(category: .general, message: "Live Activity started id=\(activity.id)")
        } catch {
            LogManager.shared.log(category: .general, message: "Live Activity failed to start: \(error)")
        }
    }

    /// Called from applicationWillTerminate. Ends the LA synchronously (blocking
    /// up to 3 s) so it clears from the lock screen before the process exits.
    /// Does not clear laEnabled — the user's preference is preserved for relaunch.
    func endOnTerminate() {
        guard let activity = current else { return }
        current = nil
        Storage.shared.laRenewBy.value = 0
        LALivenessStore.clear()
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
                LALivenessStore.clear()
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
        // the cancelled state observer cannot flip dismissedByUser=true and
        // spoil the freshly started LA.
        endingForRestart = true
        dismissedByUser = false
        Storage.shared.laRenewBy.value = 0
        Storage.shared.laRenewalFailed.value = false
        // The user explicitly asked for a fresh LA — clear any push-to-start
        // backoff that would otherwise rate-limit the Restart button silently.
        Storage.shared.laLastPushToStartAt.value = 0
        Storage.shared.laPushToStartBackoff.value = 0
        pushToStartSendsWithoutAdoption = 0
        LALivenessStore.clear()
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

    @MainActor
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
    /// Returns true if renewal was performed (caller should return early).
    private func renewIfNeeded(snapshot: GlucoseSnapshot) -> Bool {
        guard let oldActivity = current else { return false }

        let renewBy = Storage.shared.laRenewBy.value
        guard renewBy > 0, Date().timeIntervalSince1970 >= renewBy else { return false }

        let overdueBy = Date().timeIntervalSince1970 - renewBy
        LogManager.shared.log(category: .general, message: "[LA] renewal deadline passed by \(Int(overdueBy))s, requesting new LA")

        if #available(iOS 17.2, *) {
            // iOS 17.2+: renewal goes through push-to-start. The dispatch hops
            // to MainActor and returns immediately; adoption (or failure) lands
            // in the observer. Return true so performRefresh stops processing
            // this tick.
            Task { @MainActor [weak self] in
                self?.attemptPushToStartCreate(reason: "renew", oldActivity: oldActivity, snapshot: snapshot)
            }
            return true
        } else {
            return attemptLegacyRenewal(snapshot: snapshot, oldActivity: oldActivity)
        }
    }

    /// Pre-17.2 renewal (iOS 16.6 – 17.1): foreground Activity.request, mark
    /// renewal-failed if it throws. Removable when the deployment target
    /// reaches 17.2.
    private func attemptLegacyRenewal(
        snapshot: GlucoseSnapshot,
        oldActivity: Activity<GlucoseLiveActivityAttributes>
    ) -> Bool {
        let renewDeadline = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)
        let attributes = GlucoseLiveActivityAttributes(title: "LoopFollow")

        // Build the fresh snapshot with showRenewalOverlay: false — the new LA has a
        // fresh deadline so no overlay is needed from the first frame. We pass the
        // deadline as staleDate to ActivityContent below, not to Storage yet; Storage
        // is only updated after Activity.request succeeds so a crash between the two
        // can't leave the deadline permanently stuck in the future.
        let freshSnapshot = snapshot.withRenewalOverlay(false)

        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: freshSnapshot,
            seq: seq,
            reason: "renew",
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

            // Write deadline only on success — avoids a stuck future deadline if we crash
            // between the write and the Activity.request call.
            Storage.shared.laRenewBy.value = renewDeadline.timeIntervalSince1970
            bind(to: newActivity, logReason: "renew")
            Storage.shared.laRenewalFailed.value = false
            cancelRenewalFailedNotification()
            GlucoseSnapshotStore.shared.save(freshSnapshot)
            LogManager.shared.log(category: .general, message: "[LA] Live Activity renewed successfully id=\(newActivity.id)")
            return true
        } catch {
            // Renewal failed — deadline was never written, so no rollback needed.
            let isFirstFailure = !Storage.shared.laRenewalFailed.value
            Storage.shared.laRenewalFailed.value = true
            LogManager.shared.log(category: .general, message: "[LA] renewal failed, keeping existing LA: \(error)")
            if isFirstFailure {
                scheduleRenewalFailedNotification()
            }
            return false
        }
    }

    // MARK: - Push-to-start (iOS 17.2+)

    /// Single creation path for iOS 17.2+. Handles initial start, renewal, and
    /// forced restart. Verifies token + APNs credentials, applies backoff, ends
    /// the old activity (if any) before sending so the new push-to-start LA
    /// cleanly replaces it. Adoption is delivered via the `activityUpdates`
    /// observer — `handlePushToStartResult` only updates backoff/state.
    @available(iOS 17.2, *)
    @MainActor
    private func attemptPushToStartCreate(
        reason: String,
        oldActivity: Activity<GlucoseLiveActivityAttributes>?,
        snapshot: GlucoseSnapshot? = nil
    ) {
        // Validate APNs credentials up-front — push-to-start is the ONLY transport
        // on iOS 17.2+, so missing/invalid creds mean the LA will never display.
        let keyId = Storage.shared.lfKeyId.value
        let apnsKey = Storage.shared.lfApnsKey.value
        guard APNsCredentialValidator.isFullyConfigured(keyId: keyId, apnsKey: apnsKey) else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start (\(reason)) blocked — APNs credentials missing or invalid (keyId valid=\(APNsCredentialValidator.isValidKeyId(keyId)), apnsKey valid=\(APNsCredentialValidator.isValidApnsKey(apnsKey)))"
            )
            scheduleApnsCredentialsMissingNotification()
            return
        }

        let now = Date().timeIntervalSince1970
        let lastAt = Storage.shared.laLastPushToStartAt.value
        let backoff = Storage.shared.laPushToStartBackoff.value
        if lastAt > 0, now < lastAt + backoff {
            let wait = Int(lastAt + backoff - now)
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start (\(reason)) rate-limited: next allowed in \(wait)s (backoff=\(Int(backoff))s)"
            )
            return
        }

        // Build snapshot if caller didn't supply one (initial start path).
        let workingSnapshot: GlucoseSnapshot = {
            if let snapshot { return snapshot }
            let provider = StorageCurrentGlucoseStateProvider()
            return GlucoseSnapshotBuilder.build(from: provider)
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
        }()

        Task { [weak self] in
            guard let self else { return }
            await self.dispatchPushToStart(
                reason: reason,
                oldActivity: oldActivity,
                snapshot: workingSnapshot
            )
        }
    }

    @available(iOS 17.2, *)
    private func dispatchPushToStart(
        reason: String,
        oldActivity: Activity<GlucoseLiveActivityAttributes>?,
        snapshot: GlucoseSnapshot
    ) async {
        // Wait briefly for the push-to-start token to arrive — covers the
        // fresh-install case where the user toggles LA on before iOS has
        // delivered the first token via pushToStartTokenUpdates.
        var token = Storage.shared.laPushToStartToken.value
        if token.isEmpty {
            let pollIntervalNs = UInt64(LiveActivityManager.pushToStartTokenPollInterval * 1_000_000_000)
            let maxAttempts = Int(LiveActivityManager.pushToStartTokenWaitTimeout / LiveActivityManager.pushToStartTokenPollInterval)
            for attempt in 1 ... maxAttempts {
                try? await Task.sleep(nanoseconds: pollIntervalNs)
                token = Storage.shared.laPushToStartToken.value
                if !token.isEmpty {
                    LogManager.shared.log(
                        category: .general,
                        message: "[LA] push-to-start (\(reason)) token arrived after \(attempt) poll(s)"
                    )
                    break
                }
            }
        }
        guard !token.isEmpty else {
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start (\(reason)) aborted — no token after \(LiveActivityManager.pushToStartTokenWaitTimeout)s wait (iOS hasn't issued one yet)"
            )
            await MainActor.run { self.schedulePushToStartTokenMissingNotification() }
            return
        }

        // Record attempt time up-front so two refresh ticks can't double-fire.
        await MainActor.run {
            Storage.shared.laLastPushToStartAt.value = Date().timeIntervalSince1970
        }

        let nextSeq = await MainActor.run { () -> Int in
            self.seq += 1
            return self.seq
        }
        let freshSnapshot = snapshot.withRenewalOverlay(false)
        let state = GlucoseLiveActivityAttributes.ContentState(
            snapshot: freshSnapshot,
            seq: nextSeq,
            reason: reason,
            producedAt: Date(),
        )
        let staleDate = Date().addingTimeInterval(LiveActivityManager.renewalThreshold)

        let tail = String(token.suffix(8))
        LogManager.shared.log(
            category: .general,
            message: "[LA] push-to-start (\(reason)) firing token=…\(tail) seq=\(nextSeq) staleIn=\(Int(staleDate.timeIntervalSinceNow))s"
        )

        // End the old activity inline so the push-to-start cleanly replaces it.
        if let oldActivity {
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start (\(reason)) ending oldActivity=\(oldActivity.id) before send"
            )
            await oldActivity.end(nil, dismissalPolicy: .immediate)
        }

        let sendStart = Date()
        let result = await APNSClient.shared.sendLiveActivityStart(
            pushToStartToken: token,
            attributesTitle: "LoopFollow",
            state: state,
            staleDate: staleDate,
        )
        let elapsedMs = Int(Date().timeIntervalSince(sendStart) * 1000)
        LogManager.shared.log(
            category: .general,
            message: "[LA] push-to-start (\(reason)) APNs round-trip result=\(result) elapsed=\(elapsedMs)ms"
        )
        await MainActor.run {
            self.handlePushToStartResult(result, reason: reason)
        }
    }

    @available(iOS 17.2, *)
    @MainActor
    private func handlePushToStartResult(
        _ result: APNSClient.PushToStartResult,
        reason: String
    ) {
        switch result {
        case .success:
            // Adoption of the new LA runs via `activityUpdates` observation,
            // which ends the old activity, resets the renewal deadline and
            // clears `laRenewalFailed`. Apply base backoff so refresh ticks
            // between now and adoption don't re-fire push-to-start.
            Storage.shared.laPushToStartBackoff.value = LiveActivityManager.pushToStartBaseBackoff
            lastPushToStartSuccessAt = Date()
            pushToStartSendsWithoutAdoption += 1
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start (\(reason)) succeeded — awaiting activityUpdates to adopt new LA (backoff=\(Int(LiveActivityManager.pushToStartBaseBackoff))s, sendsWithoutAdoption=\(pushToStartSendsWithoutAdoption))"
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
                message: "[LA] push-to-start (\(reason)) 429 — backoff raised to \(Int(next))s"
            )
            if reason == "renew" { markRenewalFailedFromBackground() }
        case .tokenInvalid:
            // Clear the stored token so the next `pushToStartTokenUpdates`
            // delivery overwrites it. Reset backoff — no point holding off
            // while we wait for iOS to reissue.
            Storage.shared.laPushToStartToken.value = ""
            Storage.shared.laPushToStartBackoff.value = 0
            LogManager.shared.log(
                category: .general,
                message: "[LA] push-to-start (\(reason)) token invalid — cleared, awaiting new token"
            )
            if reason == "renew" { markRenewalFailedFromBackground() }
        case .failed:
            let currentBackoff = Storage.shared.laPushToStartBackoff.value
            if currentBackoff < LiveActivityManager.pushToStartBaseBackoff {
                Storage.shared.laPushToStartBackoff.value = LiveActivityManager.pushToStartBaseBackoff
            }
            if reason == "renew" { markRenewalFailedFromBackground() }
        }
    }

    /// Background renewal couldn't restart the LA via push-to-start (rate-limited,
    /// invalid token, etc.). Mark the state so the renewal overlay shows on the
    /// lock screen, and post a local notification on the first failure so the
    /// user knows to foreground the app.
    private func markRenewalFailedFromBackground() {
        let isFirstFailure = !Storage.shared.laRenewalFailed.value
        Storage.shared.laRenewalFailed.value = true
        LogManager.shared.log(
            category: .general,
            message: "[LA] push-to-start renewal failed — renewal marked failed"
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
        guard Storage.shared.laEnabled.value, !dismissedByUser else { return }
        guard !snapshotUnchanged || forceRefreshNeeded else { return }
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
            Task { @MainActor in
                self.startIfNeeded()
                if self.current != nil {
                    self.update(snapshot: snapshot, reason: reason)
                }
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
        dismissedByUser = false
        endingForRestart = false
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
        // Mark as system-initiated so the `.dismissed` delivered by end()
        // is not classified as a user swipe — that would set dismissedByUser=true
        // and block the auto-restart promised by the comment below.
        endingForRestart = true
        end()
        // Activity will restart on next BG refresh via refreshFromCurrentState()
    }

    // MARK: - Renewal Notifications

    private static let renewalNotificationID = "\(Bundle.main.bundleIdentifier ?? "loopfollow").la.renewal.failed"
    private static let apnsCredentialsNotificationID = "\(Bundle.main.bundleIdentifier ?? "loopfollow").la.apns.missing"
    private static let pushToStartTokenNotificationID = "\(Bundle.main.bundleIdentifier ?? "loopfollow").la.token.missing"

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

    private func scheduleApnsCredentialsMissingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Live Activity Setup Needed"
        content.body = "APNs credentials are missing or invalid. Configure them in Settings → APN."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: LiveActivityManager.apnsCredentialsNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false),
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func schedulePushToStartTokenMissingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Live Activity Could Not Start"
        content.body = "Live Activity could not start — try again in a moment."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: LiveActivityManager.pushToStartTokenNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false),
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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

extension Notification.Name {
    /// Posted when the user taps the Live Activity or Dynamic Island.
    /// Observers navigate to the Home or Snoozer tab as appropriate.
    static let liveActivityDidForeground = Notification.Name("liveActivityDidForeground")
}

#endif
