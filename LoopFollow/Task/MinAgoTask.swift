// LoopFollow
// MinAgoTask.swift

import Foundation

extension MainViewController {
    func scheduleMinAgoTask(initialDelay: TimeInterval = 1.0) {
        let firstRun = Date().addingTimeInterval(initialDelay)
        TaskScheduler.shared.scheduleTask(id: .minAgoUpdate, nextRun: firstRun) { [weak self] in
            guard let self = self else { return }
            self.minAgoTaskAction()
        }
    }

    func minAgoTaskAction() {
        guard bgData.count > 0, let lastBG = bgData.last else {
            DispatchQueue.main.async {
                Observable.shared.minAgoText.value = ""
                Observable.shared.bgText.value = ""
            }
            TaskScheduler.shared.rescheduleTask(id: .minAgoUpdate, to: Date().addingTimeInterval(1))
            return
        }

        let bgSeconds = lastBG.date
        let now = Date()
        let secondsAgo = now.timeIntervalSince1970 - bgSeconds

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .dropLeading

        let shouldDisplaySeconds = secondsAgo >= 270 && secondsAgo < 720 // 4.5 to 12 minutes

        if shouldDisplaySeconds {
            formatter.allowedUnits = [.minute, .second]
        } else {
            formatter.allowedUnits = [.minute]
        }

        let formattedDuration = formatter.string(from: secondsAgo) ?? ""
        let minAgoDisplayText = formattedDuration + " min ago"

        // Update UI only if the display text has changed
        if minAgoDisplayText != Observable.shared.minAgoText.value {
            DispatchQueue.main.async {
                Observable.shared.minAgoText.value = minAgoDisplayText
            }
        }

        let deltaTime = secondsAgo / 60
        Observable.shared.bgStale.value = deltaTime >= 12

        // Update badge based on staleness
        if Observable.shared.bgStale.value {
            updateBadge(val: 0)
        } else {
            updateBadge(val: Observable.shared.bg.value ?? 0)
        }

        // Determine the next run interval based on the current state
        let nextUpdateInterval: TimeInterval
        if shouldDisplaySeconds {
            // Update every second when showing seconds
            nextUpdateInterval = 1.0
        } else if secondsAgo >= 240, secondsAgo < 720 {
            // Schedule exactly at the transition point to start showing seconds
            nextUpdateInterval = 270.0 - secondsAgo
        } else {
            // Schedule exactly at the transition point to next minute
            let secondsToNextMinute = 60.0 - (secondsAgo.truncatingRemainder(dividingBy: 60.0))
            nextUpdateInterval = secondsToNextMinute
        }

        // Ensure the nextUpdateInterval is not negative or too small
        let safeNextInterval = max(nextUpdateInterval, 1.0)

        TaskScheduler.shared.rescheduleTask(id: .minAgoUpdate, to: Date().addingTimeInterval(safeNextInterval))
    }
}
