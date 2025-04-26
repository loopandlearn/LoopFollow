    //
    //  Observable.swift
    //  LoopFollow
    //
    //  Created by Jonas Björkert on 2024-07-25.
    //  Copyright © 2024 Jon Fawcett. All rights reserved.
    //

import Foundation
import HealthKit

class Observable {
    static let shared = Observable()

    var tempTarget = ObservableValue<HKQuantity?>(default: nil)
    var override = ObservableValue<String?>(default: nil)
    var lastRecBolusTriggered = ObservableValue<Double?>(default: nil)

    // Work in progress here.. 
    var bgValue = ObservableValue<Double>(default: 0.0)
    var trendArrow = ObservableValue<String>(default: "→")
    var delta = ObservableValue<Double>(default: 0.0)
    var minutesAgo = ObservableValue<Int>(default: 0)
    var alarmTitle = ObservableValue<String?>(default: nil)

    private init() {}
}
