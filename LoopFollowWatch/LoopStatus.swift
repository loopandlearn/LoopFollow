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

    // Bolus calculation values from devicestatus
    let recommendedBolus: Double?   // Loop only — direct from devicestatus
    let isf: Double?                // OpenAPS — enacted/suggested ISF (autosens-adjusted)
    let carbRatio: Double?          // OpenAPS — from reason string
    let currentTarget: Double?      // OpenAPS — enacted/suggested current_target

    // Extended OpenAPS/Trio fields surfaced in the Follow Status sheet
    let autosensRatio: Double?      // OpenAPS — sensitivityRatio (1.00 == 100%)
    let eventualBG: Double?         // OpenAPS — eventualBG
    let tdd: Double?                // OpenAPS — TDD (units)
    let minPredBG: Double?          // OpenAPS — min across all predBGs.* arrays
    let maxPredBG: Double?          // OpenAPS — max across all predBGs.* arrays
    let insulinReq: Double?         // OpenAPS — insulinReq
    let reason: String?             // OpenAPS/Loop — full reason free-text
}
