//
//  MinAgoTask.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-11.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.MinAgoText.text = ""
                self.latestMinAgoString = ""
                if let snoozer = self.tabBarController?.viewControllers?[2] as? SnoozeViewController {
                    snoozer.MinAgoLabel.text = ""
                    snoozer.BGLabel.text = ""
                    snoozer.BGLabel.attributedText = NSAttributedString(string: "")
                }
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
        if minAgoDisplayText != latestMinAgoString {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.MinAgoText.text = minAgoDisplayText
                self.latestMinAgoString = minAgoDisplayText

                if let snoozer = self.tabBarController?.viewControllers?[2] as? SnoozeViewController {
                    snoozer.MinAgoLabel.text = minAgoDisplayText

                    let bgLabelText = snoozer.BGLabel.text ?? ""
                    let attributeString = NSMutableAttributedString(string: bgLabelText)
                    attributeString.addAttribute(.strikethroughStyle,
                                                 value: NSUnderlineStyle.single.rawValue,
                                                 range: NSRange(location: 0, length: attributeString.length))
                    attributeString.addAttribute(.strikethroughColor,
                                                 value: secondsAgo >= 720 ? UIColor.systemRed : UIColor.clear,
                                                 range: NSRange(location: 0, length: attributeString.length))
                    snoozer.BGLabel.attributedText = attributeString
                }
            }
        }

        // Determine the next run interval based on the current state
        let nextUpdateInterval: TimeInterval
        if shouldDisplaySeconds {
            // Update every second when showing seconds
            nextUpdateInterval = 1.0
        } else if secondsAgo >= 240 && secondsAgo < 720 {
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
