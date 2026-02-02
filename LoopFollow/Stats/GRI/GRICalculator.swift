// LoopFollow
// GRICalculator.swift

import Foundation

struct GRICalculationResult {
    let gri: Double
    let hypoComponent: Double
    let hyperComponent: Double
}

class GRICalculator {
    /// Calculate GRI (Glucose Risk Index) from BG data
    /// GRI = (3.0 × HypoComponent) + (1.6 × HyperComponent)
    static func calculate(bgData: [ShareGlucoseData]) -> GRICalculationResult {
        guard !bgData.isEmpty else { return GRICalculationResult(gri: 0.0, hypoComponent: 0.0, hyperComponent: 0.0) }

        let vLowThreshold = 54.0
        let lowThreshold = 70.0
        let highThreshold = 180.0
        let vHighThreshold = 250.0

        var vLowCount = 0
        var lowCount = 0
        var highCount = 0
        var vHighCount = 0

        for reading in bgData {
            let glucose = Double(reading.sgv)

            if glucose < vLowThreshold {
                vLowCount += 1
            } else if glucose < lowThreshold {
                lowCount += 1
            } else if glucose > vHighThreshold {
                vHighCount += 1
            } else if glucose > highThreshold {
                highCount += 1
            }
        }

        let totalCount = Double(bgData.count)
        guard totalCount > 0 else { return GRICalculationResult(gri: 0.0, hypoComponent: 0.0, hyperComponent: 0.0) }

        let vLowPercent = (Double(vLowCount) / totalCount) * 100.0
        let lowPercent = (Double(lowCount) / totalCount) * 100.0
        let highPercent = (Double(highCount) / totalCount) * 100.0
        let vHighPercent = (Double(vHighCount) / totalCount) * 100.0

        let hypoComponent = vLowPercent + (0.8 * lowPercent)
        let hyperComponent = vHighPercent + (0.5 * highPercent)

        let gri = (3.0 * hypoComponent) + (1.6 * hyperComponent)
        return GRICalculationResult(
            gri: min(gri, 100.0),
            hypoComponent: hypoComponent,
            hyperComponent: hyperComponent
        )
    }

    static func calculateTimeSeries(bgData: [ShareGlucoseData]) -> [(date: Date, value: Double)] {
        guard !bgData.isEmpty else { return [] }

        var dailyBGData: [Date: [ShareGlucoseData]] = [:]
        let calendar = Calendar.current

        for reading in bgData {
            let date = Date(timeIntervalSince1970: reading.date)
            let dayStart = calendar.startOfDay(for: date)
            if dailyBGData[dayStart] == nil {
                dailyBGData[dayStart] = []
            }
            dailyBGData[dayStart]?.append(reading)
        }

        var griPoints: [(date: Date, value: Double)] = []
        for (date, dayData) in dailyBGData.sorted(by: { $0.key < $1.key }) {
            let dayGRIResult = calculate(bgData: dayData)
            griPoints.append((date: date, value: dayGRIResult.gri))
        }

        return griPoints
    }
}
