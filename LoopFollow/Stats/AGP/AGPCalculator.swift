// LoopFollow
// AGPCalculator.swift

import Foundation

class AGPCalculator {
    static func calculate(bgData: [ShareGlucoseData]) -> [AGPDataPoint] {
        guard !bgData.isEmpty else { return [] }

        var hourData: [Int: [Double]] = [:]
        let calendar = Calendar.current

        for reading in bgData {
            let date = Date(timeIntervalSince1970: reading.date)
            let components = calendar.dateComponents([.hour], from: date)
            let hour = components.hour ?? 0

            let glucose = Double(reading.sgv)
            let glucoseMgdL = Storage.shared.units.value == "mg/dL" ? glucose : glucose * GlucoseConversion.mmolToMgDl

            if hourData[hour] == nil {
                hourData[hour] = []
            }
            hourData[hour]?.append(glucoseMgdL)
        }

        var agpPoints: [AGPDataPoint] = []
        for hour in 0 ..< 24 {
            guard let values = hourData[hour], !values.isEmpty else { continue }

            let sorted = values.sorted()
            let p5 = PercentileCalculator.percentile(sorted, p: 0.05)
            let p25 = PercentileCalculator.percentile(sorted, p: 0.25)
            let p50 = PercentileCalculator.percentile(sorted, p: 0.50)
            let p75 = PercentileCalculator.percentile(sorted, p: 0.75)
            let p95 = PercentileCalculator.percentile(sorted, p: 0.95)

            let convert: (Double) -> Double = { value in
                Storage.shared.units.value == "mg/dL" ? value : value * GlucoseConversion.mgDlToMmolL
            }

            let minutesSinceMidnight = hour * 60

            agpPoints.append(AGPDataPoint(
                timeOfDay: minutesSinceMidnight,
                p5: convert(p5),
                p25: convert(p25),
                p50: convert(p50),
                p75: convert(p75),
                p95: convert(p95)
            ))
        }

        return agpPoints.sorted { $0.timeOfDay < $1.timeOfDay }
    }
}

class PercentileCalculator {
    static func percentile(_ sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0.0 }
        if sorted.count == 1 { return sorted[0] }

        let index = p * Double(sorted.count - 1)
        let lower = Int(index.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let weight = index - Double(lower)

        return sorted[lower] * (1.0 - weight) + sorted[upper] * weight
    }
}
