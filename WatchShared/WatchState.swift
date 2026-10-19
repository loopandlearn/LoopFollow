// LoopFollow
// WatchState.swift

import Foundation

/// Everything the watch shows, built by the phone and delivered as the
/// WatchConnectivity application context. The watch never talks to Nightscout,
/// Dexcom or APNs itself, so no credentials are part of this state.
struct WatchState: Codable, Equatable {
    static let contextKey = "watchState"

    /// When the phone built this state.
    var builtAt: Date
    /// Latest glucose state, shared with the Live Activity.
    var snapshot: GlucoseSnapshot?
    /// BG readings for the last 24 hours, oldest first.
    var readings: [WatchReading]
    /// Prediction lines as drawn on the phone's main chart.
    var predictions: [WatchPredictionLine]
    /// Trio/OpenAPS forecast drawn as a band when the phone shows the cone.
    var cone: [WatchConePoint]
    var boluses: [WatchReading]
    var carbs: [WatchReading]
    /// Range thresholds used for coloring, in mg/dL (same as the phone).
    var lowMgdl: Double
    var highMgdl: Double
    /// Mirrors the phone's "Color BG Text" setting.
    var colorBGText: Bool
    /// When the loop last reported, nil when unknown.
    var lastLoopAt: Date?
    /// "Loop", "Trio" or another uploader name; empty for CGM-only setups.
    var device: String
    /// The alarm currently sounding on the phone.
    var alarm: WatchAlarm?
    /// Present when remote commands from the watch are enabled on the phone.
    var remote: WatchRemoteConfig?

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) -> WatchState? {
        try? JSONDecoder().decode(WatchState.self, from: data)
    }
}

struct WatchReading: Codable, Equatable {
    /// Unix epoch seconds.
    let t: TimeInterval
    /// mg/dL for glucose, units for boluses, grams for carbs.
    let v: Double

    var date: Date { Date(timeIntervalSince1970: t) }
}

struct WatchPredictionLine: Codable, Equatable {
    /// Matches the phone's chart series and colors.
    enum Kind: String, Codable {
        case loop
        case zt
        case iob
        case cob
        case uam
    }

    let kind: Kind
    let points: [WatchReading]
}

struct WatchConePoint: Codable, Equatable {
    let t: TimeInterval
    let low: Double
    let high: Double

    var date: Date { Date(timeIntervalSince1970: t) }
}

struct WatchAlarm: Codable, Equatable {
    let id: UUID
    let name: String
}

struct WatchPreset: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    /// Preformatted on the phone in the user's units, e.g. "120 %, 1 h".
    let detail: String
}

struct WatchRemoteConfig: Codable, Equatable {
    enum Kind: String, Codable {
        case loop
        case trio
    }

    let kind: Kind
    let maxBolus: Double
    let bolusIncrement: Double
    let maxCarbs: Double
    let maxFat: Double
    let maxProtein: Double
    /// Trio only: a meal may carry a bolus.
    let mealWithBolus: Bool
    /// Trio only: a meal may carry fat and protein.
    let mealWithFatProtein: Bool
    /// The AID's own recommendation, as shown in the phone's bolus screen.
    let recommendedBolus: Double?
    let recommendedBolusAt: Date?
    let overridePresets: [WatchPreset]
    /// Trio only.
    let tempTargetPresets: [WatchPreset]
}
