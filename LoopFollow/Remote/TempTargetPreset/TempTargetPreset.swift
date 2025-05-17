// LoopFollow
// TempTargetPreset.swift
// Created by Jonas Björkert on 2024-07-31.

import Foundation
import HealthKit

struct TempTargetPreset: Identifiable, Codable {
    var id: UUID
    var name: String
    var target: HKQuantity
    var duration: HKQuantity

    enum CodingKeys: String, CodingKey {
        case id, name, targetValue, durationValue
    }

    init(id: UUID = UUID(), name: String, target: HKQuantity, duration: HKQuantity) {
        self.id = id
        self.name = name
        self.target = target
        self.duration = duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        let targetValue = try container.decode(Double.self, forKey: .targetValue)
        target = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: targetValue)

        let durationValue = try container.decode(Double.self, forKey: .durationValue)
        duration = HKQuantity(unit: .minute(), doubleValue: durationValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(target.doubleValue(for: .milligramsPerDeciliter), forKey: .targetValue)
        try container.encode(duration.doubleValue(for: .minute()), forKey: .durationValue)
    }
}
