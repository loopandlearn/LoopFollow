// LoopFollow
// MainViewController+updateStats.swift

import Foundation

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

            statsDisplayModel.lowPercent = String(format: "%.1f%%", stats.percentLow)
            statsDisplayModel.inRangePercent = String(format: "%.1f%%", stats.percentRange)
            statsDisplayModel.highPercent = String(format: "%.1f%%", stats.percentHigh)
            statsDisplayModel.avgBG = Localizer.toDisplayUnits(String(format: "%.0f", stats.avgBG))
            if Storage.shared.useIFCC.value {
                statsDisplayModel.estA1C = String(format: "%.0f", stats.a1C)
            } else {
                statsDisplayModel.estA1C = String(format: "%.1f", stats.a1C)
            }
            statsDisplayModel.stdDev = String(format: "%.2f", stats.stdDev)

            statsDisplayModel.pieLow = Double(stats.percentLow)
            statsDisplayModel.pieRange = Double(stats.percentRange)
            statsDisplayModel.pieHigh = Double(stats.percentHigh)
        }
    }
}
