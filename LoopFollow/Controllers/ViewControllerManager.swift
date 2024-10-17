//
//  ViewControllerManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-27.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

class ViewControllerManager {

    static let shared = ViewControllerManager()

    var alarmViewController: AlarmViewController?

    private init() {
        instantiateAlarmViewController()
    }

    private func instantiateAlarmViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        self.alarmViewController = storyboard.instantiateViewController(withIdentifier: "AlarmViewController") as? AlarmViewController
    }
}
