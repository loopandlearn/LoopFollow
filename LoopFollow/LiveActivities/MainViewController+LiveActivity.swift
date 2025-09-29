// LoopFollow
// MainViewController+LiveActivity.swift

import ActivityKit
import Foundation
import SwiftUI

extension MainViewController {
    // Persist key (scoped to this bundle id via Storage wrapper)
    private var liveActivityIdStorage: StorageValue<String?> { Storage.shared.liveActivityId }

    func currentEmoji() -> String {
        guard let last = bgData.last else { return "⌛️" }
        let v = Double(last.sgv)
        if v >= Storage.shared.highLine.value { return "🟡" }
        if v <= Storage.shared.lowLine.value { return "🔴" }
        return "🟢"
    }

    private func paletteFromObservableColor() -> Palette {
        let c = Observable.shared.bgTextColor.value
        if c == .yellow { return .yellow }
        if c == .red { return .red }
        if c == .green { return .green }
        return .primary
    }

    private func currentLAState() -> LoopFollowWidgetAttributes.ContentState {
        // Determine zone from latest BG numeric value (for emoji & island color)
        let zone: Int = {
            guard let last = bgData.last else { return 0 }
            let v = Double(last.sgv)
            if v >= Storage.shared.highLine.value { return 1 }
            if v <= Storage.shared.lowLine.value { return -1 }
            return 0
        }()

        let iobString = latestIOB?.formattedValue() ?? "0"
        let cobString = latestCOB?.formattedValue() ?? "0"
        let emoji = (zone == 1 ? "🟡" : (zone == -1 ? "🔴" : "🟢"))
        let resolvedDisplayName: String? = Storage.shared.showDisplayName.value ? Bundle.main.displayName : nil

        return .init(
            emoji: emoji,
            bg: Observable.shared.bgText.value,
            direction: Observable.shared.directionText.value,
            delta: Observable.shared.deltaText.value,
            minAgo: Observable.shared.minAgoText.value,
            iob: iobString,
            cob: cobString,
            zone: zone,
            displayName: resolvedDisplayName,
            stale: Observable.shared.bgStale.value,
            bgTextColor: paletteFromObservableColor()
        )
    }

    /// Try to attach to a previously-started LA (ID first, then any first).
    func attachExistingLiveActivityIfAny() {
        if liveActivity != nil { return }

        let activities = Activity<LoopFollowWidgetAttributes>.activities

        if let savedId = liveActivityIdStorage.value,
           let exact = activities.first(where: { $0.id == savedId })
        {
            liveActivity = exact
            return
        }

        // Fallback: grab the first if it exists.
        liveActivity = activities.first
        if let id = liveActivity?.id {
            liveActivityIdStorage.value = id
        }
    }

    /// Unconditionally start (if needed) and update the Live Activity.
    func updateLiveActivity() {
        print("LiveActivity updateLiveActivity()")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = currentLAState()

        // Ensure we’re attached or create once.
        if liveActivity == nil {
            attachExistingLiveActivityIfAny()
            if liveActivity == nil {
                do {
                    let act = try LiveActivityManager.start(
                        state: state,
                        staleAfter: 15 * 60
                    )
                    liveActivity = act
                    liveActivityIdStorage.value = act.id
                } catch {
                    print("LiveActivity start failed:", error)
                    return
                }
            }
        }

        guard let act = liveActivity else { return }
        Task {
            print("LiveActivity updating")
            await LiveActivityManager.update(act, state: state, staleAfter: 15 * 60)
        }
    }

    func endLiveActivityIfRunning(finalEmoji: String? = nil) {
        guard let act = liveActivity else { return }
        var endState = currentLAState()
        if let e = finalEmoji { endState.emoji = e }
        Task {
            await LiveActivityManager.end(act, finalState: endState, dismissalPolicy: .immediate)
            liveActivity = nil
            liveActivityIdStorage.value = nil
        }
    }
}
