// LoopFollow
// GlucoseSnapshot.swift

import Foundation

/// Canonical, source-agnostic glucose state used by
/// Live Activity, future Watch complication, and CarPlay.
///
struct GlucoseSnapshot: Codable, Equatable, Hashable {
    // MARK: - Units

    enum Unit: String, Codable, Hashable {
        case mgdl
        case mmol
    }

    // MARK: - Core Glucose

    /// Glucose value in mg/dL (canonical internal unit).
    let glucose: Double

    /// Delta in mg/dL. May be 0.0 if unchanged.
    let delta: Double

    /// Trend direction (mapped from LoopFollow state).
    let trend: Trend

    /// Timestamp of reading.
    let updatedAt: Date

    // MARK: - Secondary Metrics

    /// Insulin On Board
    let iob: Double?

    /// Carbs On Board
    let cob: Double?

    /// Projected glucose in mg/dL (if available)
    let projected: Double?

    // MARK: - Unit Context

    /// User's preferred display unit. Values are always stored in mg/dL;
    /// this tells the display layer which unit to render.
    let unit: Unit

    // MARK: - Loop Status

    /// True when LoopFollow detects the loop has not reported in 15+ minutes (Nightscout only).
    let isNotLooping: Bool

    init(
        glucose: Double,
        delta: Double,
        trend: Trend,
        updatedAt: Date,
        iob: Double?,
        cob: Double?,
        projected: Double?,
        unit: Unit,
        isNotLooping: Bool
    ) {
        self.glucose = glucose
        self.delta = delta
        self.trend = trend
        self.updatedAt = updatedAt
        self.iob = iob
        self.cob = cob
        self.projected = projected
        self.unit = unit
        self.isNotLooping = isNotLooping
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(glucose, forKey: .glucose)
        try container.encode(delta, forKey: .delta)
        try container.encode(trend, forKey: .trend)
        try container.encode(updatedAt.timeIntervalSince1970, forKey: .updatedAt)
        try container.encodeIfPresent(iob, forKey: .iob)
        try container.encodeIfPresent(cob, forKey: .cob)
        try container.encodeIfPresent(projected, forKey: .projected)
        try container.encode(unit, forKey: .unit)
        try container.encode(isNotLooping, forKey: .isNotLooping)
    }

    private enum CodingKeys: String, CodingKey {
        case glucose, delta, trend, updatedAt, iob, cob, projected, unit, isNotLooping
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        glucose = try container.decode(Double.self, forKey: .glucose)
        delta = try container.decode(Double.self, forKey: .delta)
        trend = try container.decode(Trend.self, forKey: .trend)
        updatedAt = try Date(timeIntervalSince1970: container.decode(Double.self, forKey: .updatedAt))
        iob = try container.decodeIfPresent(Double.self, forKey: .iob)
        cob = try container.decodeIfPresent(Double.self, forKey: .cob)
        projected = try container.decodeIfPresent(Double.self, forKey: .projected)
        unit = try container.decode(Unit.self, forKey: .unit)
        isNotLooping = try container.decodeIfPresent(Bool.self, forKey: .isNotLooping) ?? false
    }

    // MARK: - Derived Convenience

    /// Age of reading in seconds.
    var age: TimeInterval {
        Date().timeIntervalSince(updatedAt)
    }
}

// MARK: - Trend

extension GlucoseSnapshot {
    enum Trend: String, Codable, Hashable {
        case up
        case upSlight
        case upFast
        case flat
        case down
        case downSlight
        case downFast
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            self = Trend(rawValue: raw) ?? .unknown
        }
    }
}
