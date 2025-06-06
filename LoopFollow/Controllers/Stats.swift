// LoopFollow
// Stats.swift
// Created by Jon Fawcett on 2020-06-23.

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
    var bgDataCount: Int
    var pie: [DataStructs.pieData]

    init(bgData: [ShareGlucoseData]) {
        countLow = 0
        countRange = 0
        countHigh = 0
        totalGlucose = 0
        a1C = 0.0

        for i in 0 ..< bgData.count {
            // Set low/range/high counts for pie chart and %'s
            if Double(bgData[i].sgv) <= Storage.shared.lowLine.value {
                countLow += 1
            } else if Double(bgData[i].sgv) >= Storage.shared.highLine.value {
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

        stdDev = sqrt(partialSum / Float(bgData.count))
        if Storage.shared.units.value != "mg/dL" {
            stdDev = stdDev * Float(GlucoseConversion.mgDlToMmolL)
        }

        if Storage.shared.useIFCC.value {
            a1C = (((46.7 + Float(avgBG)) / 28.7) - 2.152) / 0.09148
        } else {
            a1C = (46.7 + Float(avgBG)) / 28.7
        }
    }
}
