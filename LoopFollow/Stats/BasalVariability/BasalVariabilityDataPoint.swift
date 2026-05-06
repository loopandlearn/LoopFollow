// LoopFollow
// BasalVariabilityDataPoint.swift

import Foundation

struct BasalVariabilityDataPoint {
    let period: TIRPeriod
    let veryBelow: Double   // < 50% of planned
    let below: Double       // 50–75% of planned
    let atPlanned: Double   // 75–125% of planned (within ±25%)
    let above: Double       // 125–150% of planned
    let veryAbove: Double   // > 150% of planned
}
