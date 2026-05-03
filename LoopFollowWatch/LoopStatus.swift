// LoopFollow
// LoopStatus.swift

import Foundation

struct LoopStatus {
    let iob: Double?
    let cob: Double?
    let basalRate: Double?
    let overrideActive: Bool
    let overrideText: String?
    let timestamp: Date

    // Predictions — Loop has one array, OpenAPS has four
    let predictions: [Double]?
    let predictionStart: Date?
    let ztPredictions: [Double]?
    let iobPredictions: [Double]?
    let cobPredictions: [Double]?
    let uamPredictions: [Double]?
    let isOpenAPS: Bool

    // Temp target (from devicestatus or treatments)
    let tempTargetActive: Bool
    let tempTargetText: String?
}
