// LoopFollow
// MainViewController+LiveActivity.swift

import ActivityKit
import Foundation

extension MainViewController {
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

        // Resolve display name in the app target; pass it to the widget (or nil if hidden)
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

    func attachExistingLiveActivityIfAny() {
        if liveActivity == nil {
            liveActivity = Activity<LoopFollowWidgetAttributes>.activities.first
        }
    }

    func updateLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = currentLAState()

        if liveActivity == nil {
            attachExistingLiveActivityIfAny()
            if liveActivity == nil {
                do {
                    liveActivity = try LiveActivityManager.start(state: state,
                                                                 name: "LoopFollow",
                                                                 staleAfter: 15 * 60)
                } catch {
                    print("LiveActivity start failed:", error)
                }
            }
        }

        guard let act = liveActivity else { return }
        Task { await LiveActivityManager.update(act, state: state, staleAfter: 15 * 60) }
    }

    func endLiveActivityIfRunning(finalEmoji: String? = nil) {
        guard let act = liveActivity else { return }
        var endState = currentLAState()
        if let e = finalEmoji { endState.emoji = e }
        Task {
            await LiveActivityManager.end(act, finalState: endState, dismissalPolicy: .immediate)
            liveActivity = nil
        }
    }
}
