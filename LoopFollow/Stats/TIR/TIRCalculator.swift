// LoopFollow
// TIRCalculator.swift

import Foundation

class TIRCalculator {
    static func calculate(bgData: [ShareGlucoseData], useTightRange: Bool = false) -> [TIRDataPoint] {
        guard !bgData.isEmpty else { return [] }

        let veryLowThreshold = 54.0
        let lowThreshold = 70.0
        let highThreshold = useTightRange ? 140.0 : 180.0
        let veryHighThreshold = 250.0
        var periodData: [TIRPeriod: [Double]] = [:]
        let calendar = Calendar.current

        for reading in bgData {
            let date = Date(timeIntervalSince1970: reading.date)
            let components = calendar.dateComponents([.hour], from: date)
            let hour = components.hour ?? 0

            let glucose = Double(reading.sgv)

            var period: TIRPeriod?
            if let hourRange = TIRPeriod.night.hourRange, hour >= hourRange.start, hour < hourRange.end {
                period = .night
            } else if let hourRange = TIRPeriod.morning.hourRange, hour >= hourRange.start, hour < hourRange.end {
                period = .morning
            } else if let hourRange = TIRPeriod.day.hourRange, hour >= hourRange.start, hour < hourRange.end {
                period = .day
            } else if let hourRange = TIRPeriod.evening.hourRange, hour >= hourRange.start, hour < hourRange.end {
                period = .evening
            }

            if let period = period {
                if periodData[period] == nil {
                    periodData[period] = []
                }
                periodData[period]?.append(glucose)
            }
        }

        var tirPoints: [TIRDataPoint] = []

        for period in [TIRPeriod.night, .morning, .day, .evening] {
            guard let readings = periodData[period], !readings.isEmpty else {
                tirPoints.append(TIRDataPoint(
                    period: period,
                    veryLow: 0.0,
                    low: 0.0,
                    inRange: 0.0,
                    high: 0.0,
                    veryHigh: 0.0
                ))
                continue
            }

            let percentages = calculatePercentages(readings: readings,
                                                   veryLowThreshold: veryLowThreshold,
                                                   lowThreshold: lowThreshold,
                                                   highThreshold: highThreshold,
                                                   veryHighThreshold: veryHighThreshold)

            tirPoints.append(TIRDataPoint(
                period: period,
                veryLow: percentages.veryLow,
                low: percentages.low,
                inRange: percentages.inRange,
                high: percentages.high,
                veryHigh: percentages.veryHigh
            ))
        }

        let allReadings = bgData.map { Double($0.sgv) }
        let averagePercentages = calculatePercentages(readings: allReadings,
                                                      veryLowThreshold: veryLowThreshold,
                                                      lowThreshold: lowThreshold,
                                                      highThreshold: highThreshold,
                                                      veryHighThreshold: veryHighThreshold)

        tirPoints.append(TIRDataPoint(
            period: .average,
            veryLow: averagePercentages.veryLow,
            low: averagePercentages.low,
            inRange: averagePercentages.inRange,
            high: averagePercentages.high,
            veryHigh: averagePercentages.veryHigh
        ))

        return tirPoints
    }

    private static func calculatePercentages(readings: [Double],
                                             veryLowThreshold: Double,
                                             lowThreshold: Double,
                                             highThreshold: Double,
                                             veryHighThreshold: Double) -> (veryLow: Double, low: Double, inRange: Double, high: Double, veryHigh: Double)
    {
        let total = Double(readings.count)
        guard total > 0 else {
            return (0.0, 0.0, 0.0, 0.0, 0.0)
        }

        var veryLowCount = 0
        var lowCount = 0
        var inRangeCount = 0
        var highCount = 0
        var veryHighCount = 0

        for glucose in readings {
            if glucose < veryLowThreshold {
                veryLowCount += 1
            } else if glucose < lowThreshold {
                lowCount += 1
            } else if glucose > veryHighThreshold {
                veryHighCount += 1
            } else if glucose > highThreshold {
                highCount += 1
            } else {
                inRangeCount += 1
            }
        }

        return (
            veryLow: (Double(veryLowCount) / total) * 100.0,
            low: (Double(lowCount) / total) * 100.0,
            inRange: (Double(inRangeCount) / total) * 100.0,
            high: (Double(highCount) / total) * 100.0,
            veryHigh: (Double(veryHighCount) / total) * 100.0
        )
    }
}
