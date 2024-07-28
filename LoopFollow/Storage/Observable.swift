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
    var statusMessage = ObservableValue<String>(default: "")

    private init() {}
}
