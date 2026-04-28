// LoopFollow
// StatsDisplayModel.swift

import Foundation

class StatsDisplayModel: ObservableObject {
    @Published var lowPercent: String = ""
    @Published var inRangePercent: String = ""
    @Published var highPercent: String = ""
    @Published var avgBG: String = ""
    @Published var estA1C: String = ""
    @Published var stdDev: String = ""
    @Published var pieLow: Double = 0
    @Published var pieRange: Double = 0
    @Published var pieHigh: Double = 0
}
