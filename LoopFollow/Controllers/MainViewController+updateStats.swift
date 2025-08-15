// LoopFollow
// MainViewController+updateStats.swift

import Charts
import Foundation
import UIKit

extension MainViewController {
    func updateStats() {
        if bgData.count > 0 {
            var lastDayOfData = bgData
            let graphHours = 24 * Storage.shared.downloadDays.value
            // If we loaded more than 1 day of data, only use the last day for the stats
            if graphHours > 24 {
                let oneDayAgo = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24)
                var startIndex = 0
                while startIndex < bgData.count, bgData[startIndex].date < oneDayAgo {
                    startIndex += 1
                }
                lastDayOfData = Array(bgData.dropFirst(startIndex))
            }

            let stats = StatsData(bgData: lastDayOfData)

            statsLowPercent.text = String(format: "%.1f%", stats.percentLow) + "%"
            statsInRangePercent.text = String(format: "%.1f%", stats.percentRange) + "%"
            statsHighPercent.text = String(format: "%.1f%", stats.percentHigh) + "%"
            statsAvgBG.text = Localizer.toDisplayUnits(String(format: "%.0f%", stats.avgBG))
            if Storage.shared.useIFCC.value {
                statsEstA1C.text = String(format: "%.0f%", stats.a1C)
            } else {
                statsEstA1C.text = String(format: "%.1f%", stats.a1C)
            }
            statsStdDev.text = String(format: "%.2f%", stats.stdDev)

            createStatsPie(pieData: stats.pie)
        }
    }

    fileprivate func createStatsPie(pieData: [DataStructs.pieData]) {
        statsPieChart.legend.enabled = false
        statsPieChart.drawEntryLabelsEnabled = false
        statsPieChart.drawHoleEnabled = false
        statsPieChart.rotationEnabled = false

        var chartEntry = [PieChartDataEntry]()
        var colors = [NSUIColor]()

        for i in 0 ..< pieData.count {
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
            for i in 0 ..< colors.count {
                set.addColor(colors[i])
            }
        }

        let data = PieChartData(dataSet: set)
        statsPieChart.data = data
    }
}
