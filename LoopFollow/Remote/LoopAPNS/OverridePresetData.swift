// LoopFollow
// OverridePresetData.swift
// Created by Daniel Mini Johansson.

import Foundation

struct OverridePresetData: Codable, Identifiable {
    let id: String
    let name: String
    let symbol: String?
    let targetRange: ClosedRange<Double>?
    let insulinNeedsScaleFactor: Double?
    let duration: TimeInterval

    enum CodingKeys: String, CodingKey {
        case name, symbol, duration
        case targetRange
        case insulinNeedsScaleFactor
    }

    init(name: String, symbol: String? = nil, targetRange: ClosedRange<Double>? = nil, insulinNeedsScaleFactor: Double? = nil, duration: TimeInterval) {
        id = UUID().uuidString
        self.name = name
        self.symbol = symbol
        self.targetRange = targetRange
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
        self.duration = duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        duration = try container.decode(TimeInterval.self, forKey: .duration)

        // Handle target range which might be stored as min/max values
        if let targetRangeDict = try? container.decode([String: Double].self, forKey: .targetRange) {
            if let min = targetRangeDict["min"], let max = targetRangeDict["max"] {
                targetRange = min ... max
            } else {
                targetRange = nil
            }
        } else {
            targetRange = nil
        }

        insulinNeedsScaleFactor = try container.decodeIfPresent(Double.self, forKey: .insulinNeedsScaleFactor)
        id = UUID().uuidString
    }

    var durationDescription: String {
        if duration == 0 {
            return "Indefinite"
        } else {
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
}

// MARK: - Codable Extensions

extension ClosedRange: Codable where Bound: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lower = try container.decode(Bound.self, forKey: .lower)
        let upper = try container.decode(Bound.self, forKey: .upper)
        self.init(uncheckedBounds: (lower: lower, upper: upper))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lowerBound, forKey: .lower)
        try container.encode(upperBound, forKey: .upper)
    }

    private enum CodingKeys: String, CodingKey {
        case lower, upper
    }
}
