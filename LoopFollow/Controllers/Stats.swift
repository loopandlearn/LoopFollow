// LoopFollow
// Stats.swift

import Foundation

class StatsData {
    var countLow: Int
    var percentLow: Float
    var percentRange: Float
    var percentHigh: Float
    var countRange: Int
    var countHigh: Int
    var totalGlucose: Int
    var avgBG: Float
    var a1C: Float
    var stdDev: Float
    var coefficientOfVariation: Float
    var bgDataCount: Int
    var pie: [DataStructs.pieData]

    init(bgData: [ShareGlucoseData]) {
        countLow = 0
        countRange = 0
        countHigh = 0
        totalGlucose = 0
        a1C = 0.0
        coefficientOfVariation = 0.0

        let thresholds = UnitSettingsStore.shared.effectiveThresholds()
        let lowThreshold = thresholds.low
        let highThreshold = thresholds.high

        for i in 0 ..< bgData.count {
            // Set low/range/high counts for pie chart and %'s
            if Double(bgData[i].sgv) < lowThreshold {
                countLow += 1
            } else if Double(bgData[i].sgv) > highThreshold {
                countHigh += 1
            } else {
                countRange += 1
            }

            // set total bg for average
            totalGlucose += bgData[i].sgv
        }

        // Set Percents
        percentLow = Float(countLow) / Float(bgData.count) * 100
        percentRange = Float(countRange) / Float(bgData.count) * 100
        percentHigh = Float(countHigh) / Float(bgData.count) * 100

        pie = [
            DataStructs.pieData(name: "low", value: Double(percentLow)),
            DataStructs.pieData(name: "range", value: Double(percentRange)),
            DataStructs.pieData(name: "high", value: Double(percentHigh)),
        ]

        // Set Average
        bgDataCount = bgData.count
        if bgDataCount < 1 { bgDataCount = 1 }
        avgBG = Float(totalGlucose / bgDataCount)

        // compute std dev (sigma)
        var partialSum: Float = 0
        for i in 0 ..< bgData.count {
            partialSum += (Float(bgData[i].sgv) - avgBG) * (Float(bgData[i].sgv) - avgBG)
        }

        let stdDevMgdL = sqrt(partialSum / Float(bgData.count))
        if avgBG > 0 {
            coefficientOfVariation = (stdDevMgdL / avgBG) * 100.0
        }
        stdDev = Float(UnitSettingsStore.shared.convertMgdlToDisplay(Double(stdDevMgdL)))

        let avgBGDisplay = UnitSettingsStore.shared.convertMgdlToDisplay(Double(avgBG))
        let metricValue: Double?
        if UnitSettingsStore.shared.glycemicMetricMode == .gmi {
            metricValue = GlycemicMetricCalculator.calculateGMI(avgGlucoseInDisplayUnits: avgBGDisplay)
        } else {
            metricValue = GlycemicMetricCalculator.calculateEhba1c(avgGlucoseInDisplayUnits: avgBGDisplay)
        }
        a1C = Float(metricValue ?? 0.0)
    }
}
