// LoopFollow
// NightScout.swift
// Created by Jon Fawcett.

import Foundation
import UIKit

extension MainViewController {
    // NS Cage Struct
    struct cageData: Codable {
        var created_at: String
    }

    struct sageData: Codable {
        var created_at: String
    }

    struct iageData: Codable {
        var created_at: String
    }

    // NS Basal Profile Struct
    struct basalProfileStruct: Codable {
        var value: Double
        var time: String
        var timeAsSeconds: Double
    }

    // NS Basal Data  Struct
    struct basalGraphStruct: Codable {
        var basalRate: Double
        var date: TimeInterval
    }

    // NS Bolus Data  Struct
    struct bolusGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
    }

    // NS Bolus Data  Struct
    struct carbGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
        var absorptionTime: Int
    }

    func clearOldTempBasal() {
        basalData.removeAll()
        updateBasalGraph()
    }

    func clearOldBolus() {
        bolusData.removeAll()
        updateBolusGraph()
    }

    func clearOldSmb() {
        smbData.removeAll()
        updateSmbGraph()
        updateChartRenderers()
    }

    func clearOldCarb() {
        carbData.removeAll()
        updateCarbGraph()
    }

    func clearOldBGCheck() {
        bgCheckData.removeAll()
        updateBGCheckGraph()
    }

    func clearOldOverride() {
        overrideGraphData.removeAll()
        updateOverrideGraph()
    }

    func clearOldTempTarget() {
        tempTargetGraphData.removeAll()
        updateTempTargetGraph()
        updateChartRenderers()
    }

    func clearOldSuspend() {
        suspendGraphData.removeAll()
        updateSuspendGraph()
    }

    func clearOldResume() {
        resumeGraphData.removeAll()
        updateResumeGraph()
    }

    func clearOldSensor() {
        sensorStartGraphData.removeAll()
        updateSensorStart()
    }

    func clearOldNotes() {
        noteGraphData.removeAll()
        updateNotes()
    }
}
