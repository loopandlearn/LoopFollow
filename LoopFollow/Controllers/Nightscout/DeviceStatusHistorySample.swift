// LoopFollow
// DeviceStatusHistorySample.swift

import Foundation

/// The fields LoopFollow graphs over time or shows for a scrubbed time,
/// extracted from one Nightscout devicestatus record. Glucose values (smoothed
/// BG, eventual BG, target, forecasts) are mg/dL.
struct DeviceStatusHistorySample: Codable, Equatable {
    /// Time of the loop cycle that produced the record.
    let date: TimeInterval
    var iob: Double?
    var cob: Double?
    /// Glucose the OpenAPS/Trio algorithm ran on (`suggested.bg`); smoothed in Trio.
    var smoothedBG: Double?
    /// Effective ISF of the loop cycle, as uploaded (Trio reports mg/dL per U).
    var isf: Double?
    /// `sensitivityRatio`: the autosens ratio, or the dynamic ratio when Dynamic ISF is on.
    var sensitivityRatio: Double?
    var forecast: Forecast?
    /// Loop: the last forecast value. OpenAPS/Trio: `eventualBG`.
    var eventualBG: Double?
    var recommendedBolus: Double?
    /// OpenAPS/Trio `current_target`.
    var target: Double?
    /// OpenAPS/Trio `CR`.
    var carbRatio: Double?
    var tdd: Double?
    var reservoir: Double?
    var pumpBattery: Double?
    var uploaderBattery: Double?
    /// Loop's active override, as reported in the record.
    var loopOverride: LoopOverride?

    struct LoopOverride: Codable, Equatable {
        let multiplier: Double?
        let minTarget: Double
        let maxTarget: Double
    }

    struct Forecast: Codable, Equatable {
        /// Time of the first value; values follow at five-minute steps.
        let start: TimeInterval
        /// Loop publishes one curve (`main`); OpenAPS/Trio publish `ZT`, `IOB`, `COB` and `UAM`.
        let curves: [String: [Int]]

        static let loopCurve = "main"
        static let openAPSCurves = ["ZT", "IOB", "COB", "UAM"]
        static let step: TimeInterval = 300
        /// Six hours, the longest forecast the graph settings allow.
        static let maxValues = 73
    }
}

enum DeviceStatusHistoryParser {
    /// Parses a devicestatus record. Returns nil for records without loop data
    /// (for example uploader-only records from a CGM app).
    static func parse(_ record: [String: Any]) -> (sample: DeviceStatusHistorySample, createdAt: Date)? {
        let createdAt = (record["created_at"] as? String).flatMap(parseDate)

        if let loop = record["loop"] as? [String: Any] {
            guard let date = (loop["timestamp"] as? String).flatMap(parseDate) ?? createdAt else { return nil }
            var sample = DeviceStatusHistorySample(date: date.timeIntervalSince1970)
            sample.iob = number((loop["iob"] as? [String: Any])?["iob"])
            sample.cob = number((loop["cob"] as? [String: Any])?["cob"])
            if let predicted = loop["predicted"] as? [String: Any],
               let values = predicted["values"] as? [Any]
            {
                let start = (predicted["startDate"] as? String).flatMap(parseDate) ?? date
                sample.forecast = forecast(start: start, curves: [DeviceStatusHistorySample.Forecast.loopCurve: values])
                sample.eventualBG = number(values.last)
            }
            sample.recommendedBolus = number(loop["recommendedBolus"])
            if let override = record["override"] as? [String: Any],
               override["active"] as? Bool == true,
               let range = override["currentCorrectionRange"] as? [String: Any],
               let minTarget = number(range["minValue"]),
               let maxTarget = number(range["maxValue"])
            {
                sample.loopOverride = .init(multiplier: number(override["multiplier"]), minTarget: minTarget, maxTarget: maxTarget)
            }
            addDeviceFields(from: record, to: &sample)
            return (sample, createdAt ?? date)
        }

        if let openAPS = record["openaps"] as? [String: Any] {
            guard let determination = openAPS["suggested"] as? [String: Any] ?? openAPS["enacted"] as? [String: Any] else { return nil }
            let determinationDate = (determination["deliverAt"] as? String ?? determination["timestamp"] as? String).flatMap(parseDate)
            guard let date = determinationDate ?? createdAt else { return nil }

            var sample = DeviceStatusHistorySample(date: date.timeIntervalSince1970)
            sample.iob = openAPSIOB(openAPS["iob"])
            sample.cob = number(determination["COB"]) ?? reasonValue("COB", in: determination["reason"] as? String)
            sample.smoothedBG = number(determination["bg"]).flatMap { $0 > 0 ? $0 : nil }
            sample.isf = number(determination["ISF"]).flatMap { $0 > 0 ? $0 : nil }
            sample.sensitivityRatio = number(determination["sensitivityRatio"]).flatMap { $0 > 0 ? $0 : nil }
            sample.eventualBG = number(determination["eventualBG"])
            sample.recommendedBolus = number(openAPS["recommendedBolus"])
            // Same convention as the live Target row: values below 40 are mmol/L.
            sample.target = number(determination["current_target"]).map { $0 < 40 ? $0 * GlucoseConversion.mmolToMgDl : $0 }
            sample.carbRatio = number(determination["CR"]).flatMap { $0 > 0 ? $0 : nil }
            sample.tdd = number(determination["TDD"]) ?? number((openAPS["enacted"] as? [String: Any])?["TDD"])
            addDeviceFields(from: record, to: &sample)
            if let predBGs = determination["predBGs"] as? [String: Any] {
                var curves: [String: [Any]] = [:]
                for name in DeviceStatusHistorySample.Forecast.openAPSCurves {
                    if let values = predBGs[name] as? [Any] { curves[name] = values }
                }
                sample.forecast = forecast(start: date, curves: curves)
            }
            return (sample, createdAt ?? date)
        }

        return nil
    }

    private static func addDeviceFields(from record: [String: Any], to sample: inout DeviceStatusHistorySample) {
        if let pump = record["pump"] as? [String: Any] {
            sample.reservoir = number(pump["reservoir"])
            sample.pumpBattery = number((pump["battery"] as? [String: Any])?["percent"])
        }
        sample.uploaderBattery = number((record["uploader"] as? [String: Any])?["battery"])
    }

    /// `openaps.iob` is a dictionary on Trio/AAPS and an array of projections on
    /// oref0 rigs, where the first element is the current value.
    private static func openAPSIOB(_ value: Any?) -> Double? {
        if let dict = value as? [String: Any] { return number(dict["iob"]) }
        if let array = value as? [[String: Any]] { return array.first.flatMap { number($0["iob"]) } }
        return nil
    }

    private static func forecast(start: Date, curves raw: [String: [Any]]) -> DeviceStatusHistorySample.Forecast? {
        var curves: [String: [Int]] = [:]
        for (name, values) in raw {
            let ints = values.prefix(DeviceStatusHistorySample.Forecast.maxValues).compactMap { value in
                number(value).map { Int(min(max($0, 0), 10000).rounded()) }
            }
            if !ints.isEmpty { curves[name] = ints }
        }
        guard !curves.isEmpty else { return nil }
        return DeviceStatusHistorySample.Forecast(start: start.timeIntervalSince1970, curves: curves)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber:
            // JSONSerialization decodes true/false as NSNumber too.
            guard CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
            let d = n.doubleValue
            return d.isFinite ? d : nil
        case let s as String:
            return Double(s)
        default:
            return nil
        }
    }

    private static func reasonValue(_ key: String, in reason: String?) -> Double? {
        guard let reason,
              let range = reason.range(of: "\\b\(key): (-?\\d+(?:\\.\\d+)?)", options: .regularExpression)
        else { return nil }
        return Double(reason[range].dropFirst(key.count + 2))
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// ISO 8601 with a `Z` or `±HH:MM` offset, with or without fractional seconds.
    static func parseDate(_ string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? wholeSecondFormatter.date(from: string)
    }

    static func formatDate(_ date: Date) -> String {
        fractionalFormatter.string(from: date)
    }
}

extension DeviceStatusHistorySample {
    init(date: TimeInterval) {
        self.date = date
    }
}
