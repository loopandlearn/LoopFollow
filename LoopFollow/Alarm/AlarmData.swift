// LoopFollow
// AlarmData.swift
// Created by Jonas Björkert on 2025-04-26.

import Foundation

struct AlarmData: Codable {
    let bgReadings: [GlucoseValue]
    let predictionData: [GlucoseValue]
    let expireDate: Date?
    let lastLoopTime: TimeInterval?
    let latestOverrideStart: TimeInterval?
    let latestOverrideEnd: TimeInterval?
    let latestTempTargetStart: TimeInterval?
    let latestTempTargetEnd: TimeInterval?
    let recBolus: Double?
    let COB: Double?
    let sageInsertTime: TimeInterval?
    let pumpInsertTime: TimeInterval?
}

/*
 //    let iob: Double?
 //    let latestBoluses: [BolusEntry]
 //    let batteryLevel: Double?
 //    let latestCarbs: [CarbEntry]
 //    let pumpVolume: Double?
 */
