// LoopFollow
// Timers.swift
// Created by Jon Fawcett on 2020-09-03.

import Foundation
import UIKit

extension MainViewController {
    func startGraphNowTimer(time: TimeInterval = 60) {
        graphNowTimer = Timer.scheduledTimer(timeInterval: time,
                                             target: self,
                                             selector: #selector(MainViewController.graphNowTimerDidEnd(_:)),
                                             userInfo: nil,
                                             repeats: true)
    }

    @objc func graphNowTimerDidEnd(_: Timer) {
        createVerticalLines()
    }
}
