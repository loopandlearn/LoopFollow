// LoopFollow
// ObservableValue.swift
// Created by Jonas Björkert on 2024-07-28.

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
        print("Setting new value: \(newValue)")
        DispatchQueue.main.async {
            self.value = newValue
        }
    }
}
