//
//  StatsView.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/23/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Charts
import UIKit


extension MainViewController {

    func updateStats()
    {
        if bgData.count > 0 {
            var lastDayOfData = bgData
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            // If we loaded more than 1 day of data, only use the last day for the stats
            if graphHours > 24 {
                let oneDayAgo = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24)
                var startIndex = 0
                while startIndex < bgData.count && bgData[startIndex].date < oneDayAgo {
                    startIndex += 1
                }
                lastDayOfData = Array(bgData.dropFirst(startIndex))
            }
            
            let stats = StatsData(bgData: lastDayOfData)
            
            statsLowPercent.text = String(format:"%.1f %%", stats.percentLow)
            statsInRangePercent.text = String(format:"%.1f %%", stats.percentRange)
            statsHighPercent.text = String(format:"%.1f %%", stats.percentHigh)
            statsAvgBG.text = bgUnits.toDisplayUnits(String(format:"%.0f", stats.avgBG))

            if UserDefaultsRepository.useIFCC.value {
                statsEstA1C.text = String(format:"%.0f", stats.a1C)
            } else {
                statsEstA1C.text = String(format:"%.1f", stats.a1C)
            }
            statsStdDev.text = String(format:"%.1f", stats.stdDev)
            
            createStatsPie(pieData: stats.pie)
        }
        
    }
    
    func createStatsPie(pieData: [DataStructs.pieData]) {
        statsPieChart.legend.enabled = false
        statsPieChart.drawEntryLabelsEnabled = false
        statsPieChart.drawHoleEnabled = false
        statsPieChart.rotationEnabled = false
        
        var chartEntry = [PieChartDataEntry]()
        var colors = [NSUIColor]()
        
        for data in pieData {
            var slice = Double(data.value)
            if slice == 0 { slice = 0.1 }
            let value = PieChartDataEntry(value: slice)
            chartEntry.append(value)

            switch data.name {
            case "high":
                colors.append(NSUIColor.systemYellow)
            case "low":
                colors.append(NSUIColor.systemRed)
            default:
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        let set = PieChartDataSet(entries: chartEntry, label: "")

        set.drawIconsEnabled = false
        set.sliceSpace = 2
        set.drawValuesEnabled = false
        set.valueLineWidth = 0
        set.formLineWidth = 0
        set.sliceSpace = 0
        
        set.colors.removeAll()
        for c in colors {
            set.addColor(c)
        }

        statsPieChart.data =  PieChartData(dataSet: set)
    }
}
