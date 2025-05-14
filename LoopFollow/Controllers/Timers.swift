//
//  Timers.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 9/3/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

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
