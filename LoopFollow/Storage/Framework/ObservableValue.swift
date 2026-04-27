// LoopFollow
// ObservableValue.swift

import Combine
import Foundation
import HealthKit
import SwiftUI

class ObservableValue<T>: ObservableObject {
    @Published var value: T

    init(default: T) {
        value = `default`
    }

    func set(_ newValue: T) {
        DispatchQueue.main.async {
            self.value = newValue
        }
    }
}
