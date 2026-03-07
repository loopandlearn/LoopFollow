// LiveActivityManager.swift
// Philippe Achkar
// 2026-03-07

import Foundation
@preconcurrency import ActivityKit
import UIKit
import os

/// Live Activity manager for LoopFollow.

@available(iOS 16.1, *)
final class LiveActivityManager {

    static let shared = LiveActivityManager()
    private init() {}

    private(set) var current: Activity<GlucoseLiveActivityAttributes>?
    private var stateObserverTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var seq: Int = 0
    private var lastUpdateTime: Date?
    private var pushToken: String?
    private var tokenObservationTask: Task<Void, Never>?

    // MARK: - Public API

    func startIfNeeded() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            LogManager.shared.log(category: .general, message: "Live Activity not authorized")
            return
        }

        if let existing = Activity<GlucoseLiveActivityAttributes>.activities.first {
            bind(to: existing, logReason: "reuse")
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

            let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(15 * 60))
            let activity = try Activity.request(attributes: attributes, content: content, pushType: .token)

            bind(to: activity, logReason: "start-new")
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
                snapshot: (GlucoseSnapshotStore.shared.load() ?? GlucoseSnapshot(
                    glucose: 0,
                    delta: 0,
                    trend: .unknown,
                    updatedAt: Date(),
                    iob: nil,
                    cob: nil,
                    projected: nil,
                    unit: .mgdl,
                    isNotLooping: false
                )),
                seq: seq,
                reason: "end",
                producedAt: Date()
            )

            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: dismissalPolicy)

            LogManager.shared.log(category: .general, message: "Live Activity ended id=\(activity.id)", isDebug: true)

            if current?.id == activity.id {
                current = nil
            }
        }
    }

    func refreshFromCurrentState(reason: String) {
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
                staleDate: Date().addingTimeInterval(15 * 60),
                relevanceScore: 100.0
            )

            if Task.isCancelled { return }

            await activity.update(content)

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
