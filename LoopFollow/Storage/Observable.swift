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
    var isLastDeviceStatusSuggested = ObservableValue<Bool>(default: false)
    var lastRecBolusTriggered = ObservableValue<Double?>(default: nil)

    private init() {}
}
