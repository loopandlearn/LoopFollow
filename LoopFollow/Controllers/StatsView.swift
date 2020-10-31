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
           let stats = StatsData(bgData: bgData)
            
            statsLowPercent.text = String(format:"%.1f%", stats.percentLow) + "%"
            statsInRangePercent.text = String(format:"%.1f%", stats.percentRange) + "%"
            statsHighPercent.text = String(format:"%.1f%", stats.percentHigh) + "%"
            statsAvgBG.text = bgUnits.toDisplayUnits(String(format:"%.0f%", stats.avgBG))
            if UserDefaultsRepository.useIFCC.value {
                statsEstA1C.text = String(format:"%.0f%", stats.a1C)
            }
            else
            {
                statsEstA1C.text = String(format:"%.1f%", stats.a1C)
            }
            statsStdDev.text = String(format:"%.2f%", stats.stdDev)
            
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
        
        for i in 0..<pieData.count{
            var slice = Double(pieData[i].value)
            if slice == 0 { slice = 0.1 }
            let value = PieChartDataEntry(value: slice)
            chartEntry.append(value)

             if pieData[i].name == "high" {
                colors.append(NSUIColor.systemYellow)
            } else if pieData[i].name == "low" {
               colors.append(NSUIColor.systemRed)
            } else {
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
        if colors.count > 0 {
            for i in 0..<colors.count{
                set.addColor(colors[i])
            }
        }
        
        let data = PieChartData(dataSet: set)
        statsPieChart.data = data
        
    }

}
