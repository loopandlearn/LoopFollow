// LoopFollow
// MainViewController+updateStats.swift

import Foundation

extension MainViewController {
    /// Start of the period both home screen stats cover: the last 24 hours, or since
    /// midnight when chosen in Settings. Midnight follows the display time zone, so a
    /// Time Zone Override is respected.
    func homeStatsPeriodStart() -> TimeInterval {
        if Storage.shared.statsSinceMidnight.value {
            return dateTimeUtils.displayCalendar().startOfDay(for: Date()).timeIntervalSince1970
        }
        return dateTimeUtils.getTimeIntervalNHoursAgo(N: 24)
    }

    func updateStats() {
        let periodStart = homeStatsPeriodStart()
        let periodData = bgData.filter { $0.date >= periodStart }

        if periodData.isEmpty {
            // Nothing in the period yet (e.g. just after midnight): show placeholders
            // rather than the previous period's numbers.
            statsDisplayModel.lowPercent = "--"
            statsDisplayModel.inRangePercent = "--"
            statsDisplayModel.highPercent = "--"
            statsDisplayModel.avgBG = "--"
            statsDisplayModel.estA1C = "--"
            statsDisplayModel.stdDev = "--"
            statsDisplayModel.pieLow = 0
            statsDisplayModel.pieRange = 0
            statsDisplayModel.pieHigh = 0
        } else {
            let stats = StatsData(bgData: periodData)

            statsDisplayModel.lowPercent = String(format: "%.1f%%", stats.percentLow)
            statsDisplayModel.inRangePercent = String(format: "%.1f%%", stats.percentRange)
            statsDisplayModel.highPercent = String(format: "%.1f%%", stats.percentHigh)
            statsDisplayModel.avgBG = Localizer.toDisplayUnits(String(format: "%.0f", stats.avgBG))

            statsDisplayModel.estA1CTitle = UnitSettingsStore.shared.glycemicMetricMode == .gmi ? "GMI:" : "Est. A1C:"
            if UnitSettingsStore.shared.glycemicOutputUnit == .mmolMol {
                statsDisplayModel.estA1C = String(format: "%.0f", stats.a1C)
            } else {
                statsDisplayModel.estA1C = String(format: "%.1f", stats.a1C)
            }

            if UnitSettingsStore.shared.variabilityMetricMode == .stdDeviation {
                statsDisplayModel.stdDevTitle = "Std Dev:"
                if UnitSettingsStore.shared.glucoseUnit == .mgdL {
                    statsDisplayModel.stdDev = String(format: "%.0f", stats.stdDev)
                } else {
                    statsDisplayModel.stdDev = String(format: "%.1f", stats.stdDev)
                }
            } else {
                statsDisplayModel.stdDevTitle = "CV:"
                statsDisplayModel.stdDev = String(format: "%.1f%%", stats.coefficientOfVariation)
            }

            statsDisplayModel.pieLow = Double(stats.percentLow)
            statsDisplayModel.pieRange = Double(stats.percentRange)
            statsDisplayModel.pieHigh = Double(stats.percentHigh)
        }
        updateTIRBand(periodStart: periodStart)
    }

    /// Range distribution for the Time in Range band over the same period as the
    /// statistics box (last 24 hours, or today since midnight).
    /// Low, in range and high follow the Range Mode chosen in Settings (TIR, TITR,
    /// TING or Custom). Very low is below 54 mg/dL and very high above 250 mg/dL, or
    /// the range's own bounds when a custom range extends past them.
    func updateTIRBand(periodStart: TimeInterval) {
        let thresholds = UnitSettingsStore.shared.effectiveBandThresholds()
        let values = bgData
            .filter { $0.date >= periodStart && $0.sgv > 0 }
            .map { Double($0.sgv) }

        statsDisplayModel.bandTitle = UnitSettingsStore.shared.timeInRangeMode.title

        let percentages = TIRCalculator.calculatePercentages(
            readings: values,
            veryLowThreshold: thresholds.veryLow,
            lowThreshold: thresholds.low,
            highThreshold: thresholds.high,
            veryHighThreshold: thresholds.veryHigh
        )

        statsDisplayModel.bandVeryLowPct = percentages.veryLow
        statsDisplayModel.bandLowPct = percentages.low
        statsDisplayModel.bandInRangePct = percentages.inRange
        statsDisplayModel.bandHighPct = percentages.high
        statsDisplayModel.bandVeryHighPct = percentages.veryHigh
        statsDisplayModel.bandHasData = !values.isEmpty
        statsDisplayModel.bandPeriod = Storage.shared.statsSinceMidnight.value ? "today" : "last 24h"
    }
}
