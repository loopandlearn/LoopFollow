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

    func updateLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            liveActivity = try LiveActivityManager.start(emoji: currentEmoji(), name: "LoopFollow", staleAfter: 3600)
        } catch {
            print("LiveActivity start failed:", error)
        }

        guard let act = liveActivity else { return }
        Task { await LiveActivityManager.update(act, emoji: currentEmoji(), staleAfter: 3600) }
    }

    func endLiveActivityIfRunning(finalEmoji: String? = nil) {
        guard let act = liveActivity else { return }
        Task {
            await LiveActivityManager.end(act, finalEmoji: finalEmoji ?? currentEmoji(), dismissalPolicy: .immediate)
            liveActivity = nil
        }
    }
}
