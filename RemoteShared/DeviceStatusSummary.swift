// LoopFollow
// DeviceStatusSummary.swift

import Foundation

/// The parts of the latest Nightscout devicestatus the watch shows when it
/// fetches on its own.
struct DeviceStatusSummary: Equatable {
    var loopAt: Date?
    var iob: Double?
    var cob: Double?
    var recommendedBolus: Double?
    var predictions: [WatchPredictionLine] = []
    var cone: [WatchConePoint] = []

    /// How far ahead predictions are drawn.
    static let predictionPoints = 36

    /// Reads a devicestatus record the way the phone does: `loop` for Loop, `openaps` for Trio.
    static func parse(_ status: [String: Any], showsCone: Bool) -> DeviceStatusSummary {
        var result = DeviceStatusSummary()
        if let loop = status["loop"] as? [String: Any] {
            result.loopAt = date(loop["timestamp"])
            result.iob = (loop["iob"] as? [String: Any])?["iob"] as? Double
            result.cob = (loop["cob"] as? [String: Any])?["cob"] as? Double
            result.recommendedBolus = loop["recommendedBolus"] as? Double
            if let predicted = loop["predicted"] as? [String: Any],
               let values = predicted["values"] as? [Double],
               let start = date(predicted["startDate"])
            {
                result.predictions = [WatchPredictionLine(kind: .loop, points: points(values, start: start))]
            }
        } else if let openaps = status["openaps"] as? [String: Any] {
            let suggested = openaps["suggested"] as? [String: Any] ?? openaps["enacted"] as? [String: Any] ?? [:]
            result.loopAt = date(suggested["deliverAt"] ?? suggested["timestamp"])
            let iob = openaps["iob"] as? [String: Any] ?? (openaps["iob"] as? [[String: Any]])?.first
            result.iob = iob?["iob"] as? Double ?? suggested["IOB"] as? Double
            result.cob = suggested["COB"] as? Double
            result.recommendedBolus = openaps["recommendedBolus"] as? Double
            if let predBGs = suggested["predBGs"] as? [String: [Double]], let start = result.loopAt {
                let lines: [(WatchPredictionLine.Kind, String)] = [(.zt, "ZT"), (.iob, "IOB"), (.cob, "COB"), (.uam, "UAM")]
                let series = lines.compactMap { kind, key in predBGs[key].map { (kind, points($0, start: start)) } }
                // The phone shows Trio's forecast as a cone or as lines; keep what it showed last.
                if showsCone {
                    result.cone = cone(series.map(\.1))
                } else {
                    result.predictions = series.map { WatchPredictionLine(kind: $0.0, points: $0.1) }
                }
            }
        }
        return result
    }

    private static func points(_ values: [Double], start: Date) -> [WatchReading] {
        values.prefix(predictionPoints + 1).enumerated().map { index, value in
            WatchReading(t: start.timeIntervalSince1970 + Double(index) * 300, v: value)
        }
    }

    /// Same construction as the phone: the shortest series sets the length, min and max per step.
    private static func cone(_ series: [[WatchReading]]) -> [WatchConePoint] {
        guard let length = series.map(\.count).min(), length > 0 else { return [] }
        return (0 ..< length).map { index in
            let values = series.map { $0[index].v }
            var low = values.min() ?? 0
            var high = values.max() ?? 0
            if low == high {
                low -= 1
                high += 1
            }
            return WatchConePoint(t: series[0][index].t, low: low, high: high)
        }
    }

    // MARK: - Dates

    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoNoFraction = ISO8601DateFormatter()

    static func date(_ value: Any?) -> Date? {
        if let number = value as? Double {
            return Date(timeIntervalSince1970: number > 1e11 ? number / 1000 : number)
        }
        guard let string = value as? String else { return nil }
        return iso.date(from: string) ?? isoNoFraction.date(from: string)
    }
}
