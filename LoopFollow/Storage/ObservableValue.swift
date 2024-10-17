//
//  ObservableValue.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-25.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import Combine
import HealthKit
import SwiftUI

class ObservableValue<T>: ObservableObject {
    @Published var value: T

    init(default: T) {
        self.value = `default`
    }

    func set(_ newValue: T) {
        print("Setting new value: \(newValue)")
        DispatchQueue.main.async {
            self.value = newValue
        }
    }
}
