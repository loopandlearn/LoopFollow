//
//  TempTargetPresetManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-31.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import HealthKit
import Combine

class TempTargetPresetManager: ObservableObject {
    static let shared = TempTargetPresetManager()

    @Published var presets: [TempTargetPreset] = []

    private let presetsKey = "tempTargetPresets"

    private init() {
        loadPresets()
    }

    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey) {
            if let decodedPresets = try? JSONDecoder().decode([TempTargetPreset].self, from: data) {
                self.presets = decodedPresets
            }
        }
    }

    func savePresets() {
        if let encodedData = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encodedData, forKey: presetsKey)
        }
    }

    func addPreset(name: String, target: HKQuantity, duration: HKQuantity) {
        if let index = presets.firstIndex(where: { $0.name == name }) {
            presets[index] = TempTargetPreset(name: name, target: target, duration: duration)
        } else {
            presets.append(TempTargetPreset(name: name, target: target, duration: duration))
        }
        savePresets()
    }

    func deletePreset(at index: Int) {
        presets.remove(at: index)
        savePresets()
    }
}
