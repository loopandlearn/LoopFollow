// LoopFollow
// InsulinForecast.swift

import Foundation

/// Where IOB and insulin activity are heading for the insulin already
/// delivered and the running temp basal until it ends, with no further
/// dosing. OpenAPS/Trio upload it as `openaps.iobForecast`; for Loop it is
/// computed from treatments (see `LoopInsulinActivity`).
struct InsulinForecast: Equatable {
    struct Point: Equatable {
        let date: TimeInterval
        let iob: Double
        /// U/h.
        let activity: Double
    }

    let points: [Point]

    static let step: TimeInterval = 5 * 60

    /// Reads `openaps.iobForecast` (`iob` in U and `activity` in U/min, every
    /// five minutes from `openaps.iob.time`).
    static func parseOpenAPS(_ openAPS: [String: Any]) -> InsulinForecast? {
        guard let forecast = openAPS["iobForecast"] as? [String: Any],
              let iob = forecast["iob"] as? [Any],
              let activity = forecast["activity"] as? [Any],
              let timeString = (openAPS["iob"] as? [String: Any])?["time"] as? String,
              let start = DeviceStatusHistoryParser.parseDate(timeString)?.timeIntervalSince1970
        else { return nil }

        let points = zip(iob, activity).enumerated().compactMap { index, pair -> Point? in
            guard let iob = (pair.0 as? NSNumber)?.doubleValue,
                  let activity = (pair.1 as? NSNumber)?.doubleValue,
                  iob.isFinite, activity.isFinite
            else { return nil }
            return Point(date: start + Double(index) * step, iob: iob, activity: activity * 60)
        }
        return points.count > 1 ? InsulinForecast(points: points) : nil
    }

    /// The points up to `end`.
    func clipped(to end: TimeInterval) -> InsulinForecast? {
        let kept = points.filter { $0.date <= end }
        return kept.count > 1 ? InsulinForecast(points: kept) : nil
    }
}
