// LoopFollow
// StorageCurrentGlucoseStateProvider.swift

import Foundation

/// Reads the latest glucose state from LoopFollow's Storage and Observable layers.
/// This is the only file in the pipeline that is allowed to touch Storage.shared
/// or Observable.shared — all other layers read exclusively from this provider.
struct StorageCurrentGlucoseStateProvider: CurrentGlucoseStateProviding {
    // MARK: - Core Glucose

    var glucoseMgdl: Double? {
        guard let bg = Observable.shared.bg.value, bg > 0 else { return nil }
        return Double(bg)
    }

    var deltaMgdl: Double? {
        Storage.shared.lastDeltaMgdl.value
    }

    var projectedMgdl: Double? {
        Storage.shared.projectedBgMgdl.value
    }

    var updatedAt: Date? {
        guard let t = Storage.shared.lastBgReadingTimeSeconds.value else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    var trendCode: String? {
        Storage.shared.lastTrendCode.value
    }

    // MARK: - Secondary Metrics

    var iob: Double? {
        Storage.shared.lastIOB.value
    }

    var cob: Double? {
        Storage.shared.lastCOB.value
    }

    // MARK: - Extended Metrics

    var override: String? {
        Observable.shared.override.value
    }

    var recBolus: Double? {
        Observable.shared.deviceRecBolus.value
    }

    var battery: Double? {
        Observable.shared.deviceBatteryLevel.value
    }

    var pumpBattery: Double? {
        Observable.shared.pumpBatteryLevel.value
    }

    var basalRate: String {
        Storage.shared.lastBasal.value
    }

    var pumpReservoirU: Double? {
        Storage.shared.lastPumpReservoirU.value
    }

    var autosens: Double? {
        Storage.shared.lastAutosens.value
    }

    var tdd: Double? {
        Storage.shared.lastTdd.value
    }

    var targetLowMgdl: Double? {
        Storage.shared.lastTargetLowMgdl.value
    }

    var targetHighMgdl: Double? {
        Storage.shared.lastTargetHighMgdl.value
    }

    var isfMgdlPerU: Double? {
        Storage.shared.lastIsfMgdlPerU.value
    }

    var carbRatio: Double? {
        Storage.shared.lastCarbRatio.value
    }

    var carbsToday: Double? {
        Storage.shared.lastCarbsToday.value
    }

    var profileName: String? {
        let raw = Storage.shared.lastProfileName.value
        return raw.isEmpty ? nil : raw
    }

    var sageInsertTime: TimeInterval {
        Storage.shared.sageInsertTime.value
    }

    var cageInsertTime: TimeInterval {
        Storage.shared.cageInsertTime.value
    }

    var iageInsertTime: TimeInterval {
        Storage.shared.iageInsertTime.value
    }

    var minBgMgdl: Double? {
        Storage.shared.lastMinBgMgdl.value
    }

    var maxBgMgdl: Double? {
        Storage.shared.lastMaxBgMgdl.value
    }

    // MARK: - Loop Status

    var isNotLooping: Bool {
        let lastLoopTime = Storage.shared.lastLoopTime.value
        guard lastLoopTime > 0, !Storage.shared.url.value.isEmpty else { return false }
        return Date().timeIntervalSince1970 - lastLoopTime >= 15 * 60
    }

    // MARK: - Renewal

    var showRenewalOverlay: Bool {
        let renewBy = Storage.shared.laRenewBy.value
        let now = Date().timeIntervalSince1970
        return renewBy > 0 && now >= renewBy - LiveActivityManager.renewalWarning
    }
}
