// LoopFollow
// WatchState.swift

import Foundation

/// Everything the watch shows, built by the phone and delivered as the
/// WatchConnectivity application context. The watch never talks to Nightscout,
/// Dexcom or APNs itself, so no credentials are part of this state.
struct WatchState: Codable, Equatable {
    static let contextKey = "watchState"

    /// When this state was built, by the phone or by the watch itself.
    var builtAt: Date
    var source: WatchDataSource
    /// When the phone last built a state; info rows, presets and guardrails date from then.
    var phoneBuiltAt: Date
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
    /// Override periods in the last 24 hours, oldest first; nil from the watch's own fetch.
    var overrides: [WatchOverride]?
    /// Range thresholds used for coloring, in mg/dL (same as the phone).
    var lowMgdl: Double
    var highMgdl: Double
    /// Mirrors the phone's "Color BG Text" setting.
    var colorBGText: Bool
    /// The phone's visible info table rows, in its order and with its coloring.
    var infoRows: [WatchInfoRow]
    /// The statistics shown under the phone's chart.
    var stats: WatchStats?
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

enum WatchDataSource: String, Codable {
    /// Built and sent by the phone.
    case phone
    /// Fetched by the watch from Nightscout or Dexcom while the phone was out of reach.
    case watch
}

struct WatchReading: Codable, Equatable {
    /// Unix epoch seconds.
    let t: TimeInterval
    /// mg/dL for glucose, units for boluses, grams for carbs.
    let v: Double

    var date: Date { Date(timeIntervalSince1970: t) }
}

/// One override period, as drawn in the band at the top of the phone's chart.
struct WatchOverride: Codable, Equatable {
    /// Unix epoch seconds.
    let start: TimeInterval
    let end: TimeInterval
    let name: String
    /// Insulin needs as a percentage of normal; nil when unchanged.
    let percent: Int?

    var startDate: Date { Date(timeIntervalSince1970: start) }
    var endDate: Date { Date(timeIntervalSince1970: end) }
}

extension WatchState {
    /// The override running at `date`, if any.
    func activeOverride(at date: Date) -> WatchOverride? {
        overrides?.last { $0.startDate <= date && date < $0.endDate }
    }
}

/// The phone's statistics panel, formatted on the phone.
struct WatchStats: Codable, Equatable {
    var lowPercent: String
    var inRangePercent: String
    var highPercent: String
    var avgBG: String
    var estA1CTitle: String
    var estA1C: String
    var stdDevTitle: String
    var stdDev: String
    var pieLow: Double
    var pieRange: Double
    var pieHigh: Double
}

struct WatchInfoRow: Codable, Equatable {
    let name: String
    let value: String
    /// Threshold coloring from the phone's Info Display settings; nil uses the default text color.
    let level: InfoColorLevel?
}

/// Threshold band of an info table value, shared by the phone and the watch.
enum InfoColorLevel: String, Codable {
    case normal
    case warning
    case urgent
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
    /// Raw values the watch needs to send the preset without the phone: the
    /// duration (0 = indefinite) and, for temp targets, the target in mg/dL.
    var durationSeconds: Double = 0
    var targetMgdl: Double?
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
    var recommendedBolus: Double?
    var recommendedBolusAt: Date?
    let overridePresets: [WatchPreset]
    /// Trio only.
    let tempTargetPresets: [WatchPreset]
    /// The phone's Quick-Pick suggestions for this time of day.
    let quickPickBoluses: [Double]
    let quickPickMeals: [WatchMealPick]
}

struct WatchMealPick: Codable, Equatable {
    let carbs: Double
    let fat: Double
    let protein: Double
    let bolus: Double
}
