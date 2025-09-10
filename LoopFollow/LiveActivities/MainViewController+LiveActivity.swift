// LoopFollow
// MainViewController+LiveActivity.swift

import ActivityKit
import Foundation
import QuartzCore

// MARK: - Throttle/dedupe gate for Live Activity updates

private final class LAUpdateGate {
    static let shared = LAUpdateGate()
    private init() {}

    private var lastSentState: LoopFollowWidgetAttributes.ContentState?
    private var lastUpdateAt: CFTimeInterval = 0
    private var pendingWorkItem: DispatchWorkItem?

    /// Minimum time between updates pushed to the system
    var minInterval: TimeInterval = 1.5

    func schedule(
        state: LoopFollowWidgetAttributes.ContentState,
        perform: @escaping (LoopFollowWidgetAttributes.ContentState) -> Void
    ) {
        // Dedupe identical visible state
        if let last = lastSentState, last == state {
            return
        }

        let now = CACurrentMediaTime()
        let wait = max(0, minInterval - (now - lastUpdateAt))

        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            perform(state)
            self.lastSentState = state
            self.lastUpdateAt = CACurrentMediaTime()
        }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: work)
    }

    func reset() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lastSentState = nil
        lastUpdateAt = 0
    }
}

extension MainViewController {
    private var liveActivityIdStorage: StorageValue<String?> { Storage.shared.liveActivityId }

    func currentEmoji() -> String {
        guard let last = bgData.last else { return "⌛️" }
        let v = Double(last.sgv)
        if v >= Storage.shared.highLine.value { return "🟡" }
        if v <= Storage.shared.lowLine.value { return "🔴" }
        return "🟢"
    }

    private func currentLAState() -> LoopFollowWidgetAttributes.ContentState {
        let bgString: String
        let dirString: String
        let deltaString: String
        let minAgo: String
        let zone: Int

        if let last = bgData.last {
            bgString = Localizer.toDisplayUnits(String(last.sgv))
            let v = Double(last.sgv)
            if v >= Storage.shared.highLine.value { zone = 1 }
            else if v <= Storage.shared.lowLine.value { zone = -1 }
            else { zone = 0 }

            dirString = bgDirectionGraphic(last.direction ?? "")

            var deltaBG = 0
            if bgData.count > 1 { deltaBG = last.sgv - bgData[bgData.count - 2].sgv }
            if deltaBG < 0 { deltaString = Localizer.toDisplayUnits(String(deltaBG)) }
            else if deltaBG > 0 { deltaString = "+" + Localizer.toDisplayUnits(String(deltaBG)) }
            else { deltaString = "0" }

            let minutes = max(0, Int(Date().timeIntervalSince1970 - last.date) / 60)
            minAgo = minutes == 0 ? "now" : "\(minutes)m"
        } else {
            bgString = "–"
            dirString = "-"
            deltaString = "–"
            minAgo = "–"
            zone = 0
        }

        let iobString = latestIOB?.formattedValue() ?? "0"
        let cobString = latestCOB?.formattedValue() ?? "0"
        let emoji = (zone == 1 ? "🟡" : (zone == -1 ? "🔴" : "🟢"))

        let resolvedDisplayName: String? = Storage.shared.showDisplayName.value ? Bundle.main.displayName : nil

        return .init(
            emoji: emoji,
            bg: bgString,
            direction: dirString,
            delta: deltaString,
            minAgo: minAgo,
            iob: iobString,
            cob: cobString,
            zone: zone,
            displayName: resolvedDisplayName
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

    func updateLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = currentLAState()

        LAUpdateGate.shared.schedule(state: state) { [weak self] scheduledState in
            guard let self else { return }

            if self.liveActivity == nil {
                self.attachExistingLiveActivityIfAny()
                if self.liveActivity == nil {
                    do {
                        let act = try LiveActivityManager.start(
                            state: scheduledState,
                            staleAfter: 15 * 60
                        )
                        self.liveActivity = act
                        self.liveActivityIdStorage.value = act.id
                    } catch {
                        print("LiveActivity start failed:", error)
                        return
                    }
                }
            }

            guard let act = self.liveActivity else { return }
            Task {
                await LiveActivityManager.update(act, state: scheduledState, staleAfter: 15 * 60)
            }
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
            LAUpdateGate.shared.reset()
        }
    }
}
