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

        /// Human-readable display string for the unit (e.g. "mg/dL" or "mmol/L").
        var displayName: String {
            switch self {
            case .mgdl: return "mg/dL"
            case .mmol: return "mmol/L"
            }
        }
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

    // MARK: - Extended InfoType Metrics

    /// Active override name (nil if no active override)
    let override: String?

    /// Recommended bolus in units (nil if not available)
    let recBolus: Double?

    /// CGM/uploader device battery % (nil if not available)
    let battery: Double?

    /// Pump battery % (nil if not available)
    let pumpBattery: Double?

    /// Formatted current basal rate string (empty if not available)
    let basalRate: String

    /// Pump reservoir in units (nil if >50U or unknown)
    let pumpReservoirU: Double?

    /// Autosensitivity ratio, e.g. 0.9 = 90% (nil if not available)
    let autosens: Double?

    /// Total daily dose in units (nil if not available)
    let tdd: Double?

    /// BG target low in mg/dL (nil if not available)
    let targetLowMgdl: Double?

    /// BG target high in mg/dL (nil if not available)
    let targetHighMgdl: Double?

    /// Insulin Sensitivity Factor in mg/dL per unit (nil if not available)
    let isfMgdlPerU: Double?

    /// Carb ratio in g per unit (nil if not available)
    let carbRatio: Double?

    /// Total carbs entered today in grams (nil if not available)
    let carbsToday: Double?

    /// Active profile name (nil if not available)
    let profileName: String?

    /// Sensor insert time as Unix epoch seconds UTC (0 = not set)
    let sageInsertTime: TimeInterval

    /// Cannula insert time as Unix epoch seconds UTC (0 = not set)
    let cageInsertTime: TimeInterval

    /// Insulin/pod insert time as Unix epoch seconds UTC (0 = not set)
    let iageInsertTime: TimeInterval

    /// Min predicted BG in mg/dL (nil if not available)
    let minBgMgdl: Double?

    /// Max predicted BG in mg/dL (nil if not available)
    let maxBgMgdl: Double?

    // MARK: - Unit Context

    /// User's preferred display unit. Values are always stored in mg/dL;
    /// this tells the display layer which unit to render.
    let unit: Unit

    // MARK: - Loop Status

    /// True when LoopFollow detects the loop has not reported in 15+ minutes (Nightscout only).
    let isNotLooping: Bool

    // MARK: - Renewal

    /// True when the Live Activity is within renewalWarning seconds of its renewal deadline.
    /// The extension renders a "Tap to update" overlay so the user knows renewal is imminent.
    let showRenewalOverlay: Bool

    // MARK: - Init

    init(
        glucose: Double,
        delta: Double,
        trend: Trend,
        updatedAt: Date,
        iob: Double?,
        cob: Double?,
        projected: Double?,
        override: String? = nil,
        recBolus: Double? = nil,
        battery: Double? = nil,
        pumpBattery: Double? = nil,
        basalRate: String = "",
        pumpReservoirU: Double? = nil,
        autosens: Double? = nil,
        tdd: Double? = nil,
        targetLowMgdl: Double? = nil,
        targetHighMgdl: Double? = nil,
        isfMgdlPerU: Double? = nil,
        carbRatio: Double? = nil,
        carbsToday: Double? = nil,
        profileName: String? = nil,
        sageInsertTime: TimeInterval = 0,
        cageInsertTime: TimeInterval = 0,
        iageInsertTime: TimeInterval = 0,
        minBgMgdl: Double? = nil,
        maxBgMgdl: Double? = nil,
        unit: Unit,
        isNotLooping: Bool,
        showRenewalOverlay: Bool = false,
    ) {
        self.glucose = glucose
        self.delta = delta
        self.trend = trend
        self.updatedAt = updatedAt
        self.iob = iob
        self.cob = cob
        self.projected = projected
        self.override = override
        self.recBolus = recBolus
        self.battery = battery
        self.pumpBattery = pumpBattery
        self.basalRate = basalRate
        self.pumpReservoirU = pumpReservoirU
        self.autosens = autosens
        self.tdd = tdd
        self.targetLowMgdl = targetLowMgdl
        self.targetHighMgdl = targetHighMgdl
        self.isfMgdlPerU = isfMgdlPerU
        self.carbRatio = carbRatio
        self.carbsToday = carbsToday
        self.profileName = profileName
        self.sageInsertTime = sageInsertTime
        self.cageInsertTime = cageInsertTime
        self.iageInsertTime = iageInsertTime
        self.minBgMgdl = minBgMgdl
        self.maxBgMgdl = maxBgMgdl
        self.unit = unit
        self.isNotLooping = isNotLooping
        self.showRenewalOverlay = showRenewalOverlay
    }

    // MARK: - Derived Convenience

    /// Age of reading in seconds.
    var age: TimeInterval {
        Date().timeIntervalSince(updatedAt)
    }

    /// Returns a copy of this snapshot with `showRenewalOverlay` set to the given value.
    /// All other fields are preserved exactly. Use this instead of manually copying
    /// every field when only the overlay flag needs to change.
    func withRenewalOverlay(_ value: Bool) -> GlucoseSnapshot {
        GlucoseSnapshot(
            glucose: glucose,
            delta: delta,
            trend: trend,
            updatedAt: updatedAt,
            iob: iob,
            cob: cob,
            projected: projected,
            override: override,
            recBolus: recBolus,
            battery: battery,
            pumpBattery: pumpBattery,
            basalRate: basalRate,
            pumpReservoirU: pumpReservoirU,
            autosens: autosens,
            tdd: tdd,
            targetLowMgdl: targetLowMgdl,
            targetHighMgdl: targetHighMgdl,
            isfMgdlPerU: isfMgdlPerU,
            carbRatio: carbRatio,
            carbsToday: carbsToday,
            profileName: profileName,
            sageInsertTime: sageInsertTime,
            cageInsertTime: cageInsertTime,
            iageInsertTime: iageInsertTime,
            minBgMgdl: minBgMgdl,
            maxBgMgdl: maxBgMgdl,
            unit: unit,
            isNotLooping: isNotLooping,
            showRenewalOverlay: value,
        )
    }

    // MARK: - Codable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(glucose, forKey: .glucose)
        try container.encode(delta, forKey: .delta)
        try container.encode(trend, forKey: .trend)
        try container.encode(updatedAt.timeIntervalSince1970, forKey: .updatedAt)
        try container.encodeIfPresent(iob, forKey: .iob)
        try container.encodeIfPresent(cob, forKey: .cob)
        try container.encodeIfPresent(projected, forKey: .projected)
        try container.encodeIfPresent(override, forKey: .override)
        try container.encodeIfPresent(recBolus, forKey: .recBolus)
        try container.encodeIfPresent(battery, forKey: .battery)
        try container.encodeIfPresent(pumpBattery, forKey: .pumpBattery)
        try container.encode(basalRate, forKey: .basalRate)
        try container.encodeIfPresent(pumpReservoirU, forKey: .pumpReservoirU)
        try container.encodeIfPresent(autosens, forKey: .autosens)
        try container.encodeIfPresent(tdd, forKey: .tdd)
        try container.encodeIfPresent(targetLowMgdl, forKey: .targetLowMgdl)
        try container.encodeIfPresent(targetHighMgdl, forKey: .targetHighMgdl)
        try container.encodeIfPresent(isfMgdlPerU, forKey: .isfMgdlPerU)
        try container.encodeIfPresent(carbRatio, forKey: .carbRatio)
        try container.encodeIfPresent(carbsToday, forKey: .carbsToday)
        try container.encodeIfPresent(profileName, forKey: .profileName)
        try container.encode(sageInsertTime, forKey: .sageInsertTime)
        try container.encode(cageInsertTime, forKey: .cageInsertTime)
        try container.encode(iageInsertTime, forKey: .iageInsertTime)
        try container.encodeIfPresent(minBgMgdl, forKey: .minBgMgdl)
        try container.encodeIfPresent(maxBgMgdl, forKey: .maxBgMgdl)
        try container.encode(unit, forKey: .unit)
        try container.encode(isNotLooping, forKey: .isNotLooping)
        try container.encode(showRenewalOverlay, forKey: .showRenewalOverlay)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        glucose = try container.decode(Double.self, forKey: .glucose)
        delta = try container.decode(Double.self, forKey: .delta)
        trend = try container.decode(Trend.self, forKey: .trend)
        updatedAt = try Date(timeIntervalSince1970: container.decode(Double.self, forKey: .updatedAt))
        iob = try container.decodeIfPresent(Double.self, forKey: .iob)
        cob = try container.decodeIfPresent(Double.self, forKey: .cob)
        projected = try container.decodeIfPresent(Double.self, forKey: .projected)
        override = try container.decodeIfPresent(String.self, forKey: .override)
        recBolus = try container.decodeIfPresent(Double.self, forKey: .recBolus)
        battery = try container.decodeIfPresent(Double.self, forKey: .battery)
        pumpBattery = try container.decodeIfPresent(Double.self, forKey: .pumpBattery)
        basalRate = try container.decodeIfPresent(String.self, forKey: .basalRate) ?? ""
        pumpReservoirU = try container.decodeIfPresent(Double.self, forKey: .pumpReservoirU)
        autosens = try container.decodeIfPresent(Double.self, forKey: .autosens)
        tdd = try container.decodeIfPresent(Double.self, forKey: .tdd)
        targetLowMgdl = try container.decodeIfPresent(Double.self, forKey: .targetLowMgdl)
        targetHighMgdl = try container.decodeIfPresent(Double.self, forKey: .targetHighMgdl)
        isfMgdlPerU = try container.decodeIfPresent(Double.self, forKey: .isfMgdlPerU)
        carbRatio = try container.decodeIfPresent(Double.self, forKey: .carbRatio)
        carbsToday = try container.decodeIfPresent(Double.self, forKey: .carbsToday)
        profileName = try container.decodeIfPresent(String.self, forKey: .profileName)
        sageInsertTime = try container.decodeIfPresent(Double.self, forKey: .sageInsertTime) ?? 0
        cageInsertTime = try container.decodeIfPresent(Double.self, forKey: .cageInsertTime) ?? 0
        iageInsertTime = try container.decodeIfPresent(Double.self, forKey: .iageInsertTime) ?? 0
        minBgMgdl = try container.decodeIfPresent(Double.self, forKey: .minBgMgdl)
        maxBgMgdl = try container.decodeIfPresent(Double.self, forKey: .maxBgMgdl)
        unit = try container.decode(Unit.self, forKey: .unit)
        isNotLooping = try container.decodeIfPresent(Bool.self, forKey: .isNotLooping) ?? false
        showRenewalOverlay = try container.decodeIfPresent(Bool.self, forKey: .showRenewalOverlay) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case glucose, delta, trend, updatedAt
        case iob, cob, projected
        case override, recBolus, battery, pumpBattery, basalRate, pumpReservoirU
        case autosens, tdd, targetLowMgdl, targetHighMgdl, isfMgdlPerU, carbRatio, carbsToday
        case profileName, sageInsertTime, cageInsertTime, iageInsertTime, minBgMgdl, maxBgMgdl
        case unit, isNotLooping, showRenewalOverlay
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
