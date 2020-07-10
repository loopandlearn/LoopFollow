//
//  Stats.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/23/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

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
    var pie: [DataStructs.pieData]
    
    init(bgData: [DataStructs.sgvData]) {
        
        self.countLow = 0
        self.countRange = 0
        self.countHigh = 0
        self.totalGlucose = 0
        self.a1C = 0.0
        
        for i in 0..<bgData.count {
            // Set low/range/high counts for pie chart and %'s
            if Float(bgData[i].sgv) <= UserDefaultsRepository.lowLine.value {
                self.countLow += 1
            } else if Float(bgData[i].sgv) >= UserDefaultsRepository.highLine.value {
                self.countHigh += 1
            } else {
                self.countRange += 1
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
            DataStructs.pieData(name: "high", value: Double(percentHigh))]
        
        // Set Average
        avgBG = Float(totalGlucose / bgData.count)
        
        if UserDefaultsRepository.units.value == "mg/dL" {
            a1C = (46.7 + Float(avgBG)) / 28.7
        } else {
            a1C = (46.7 + Float(avgBG)) / 28.7
            // Keep this for later.
            // https://github.com/nightscout/nightguard/pull/72
            // a1C = (((46.7 + Float(avgBG)) / 28.7) - 2.152) / 0.09148
        }
         
        // compute std dev (sigma)
        var partialSum: Float = 0;
        for i in 0..<bgData.count {
            partialSum += (Float(bgData[i].sgv) - avgBG) * ( Float(bgData[i].sgv) - avgBG)
        }
        stdDev = sqrt(partialSum / Float(bgData.count))
    }

}
