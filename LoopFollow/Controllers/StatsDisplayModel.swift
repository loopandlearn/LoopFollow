// LoopFollow
// StatsDisplayModel.swift

import Foundation

class StatsDisplayModel: ObservableObject {
    @Published var lowPercent: String = ""
    @Published var inRangePercent: String = ""
    @Published var highPercent: String = ""
    @Published var avgBG: String = ""
    @Published var estA1C: String = ""
    @Published var estA1CTitle: String = "Est A1C:"
    @Published var stdDev: String = ""
    @Published var stdDevTitle: String = "Std Dev:"
    @Published var pieLow: Double = 0
    @Published var pieRange: Double = 0
    @Published var pieHigh: Double = 0

    // Time in Range band (today since midnight)
    @Published var bandTitle: String = "Time in Range"
    @Published var bandHasData: Bool = false
    @Published var bandVeryLowPct: Double = 0
    @Published var bandLowPct: Double = 0
    @Published var bandInRangePct: Double = 0
    @Published var bandHighPct: Double = 0
}
