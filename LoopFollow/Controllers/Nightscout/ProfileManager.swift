//
//  ProfileManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-12.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

struct ProfileManager {
    var isfSchedule: [TimeValue]
    var basalSchedule: [TimeValue]
    var carbRatioSchedule: [TimeValue]
    var overrides: [Override]
    var units: String
    var timezone: String
    var defaultProfile: String

    struct TimeValue {
        let timeAsSeconds: Int
        let value: Double
    }

    struct Override {
        let name: String
        let targetRange: [Double]
        let duration: Int
        let insulinNeedsScaleFactor: Double
        let symbol: String
    }

    init() {
        // Initialize with default values
        self.isfSchedule = []
        self.basalSchedule = []
        self.carbRatioSchedule = []
        self.overrides = []
        self.units = "mmol/L"
        self.timezone = "UTC"
        self.defaultProfile = ""
    }

    mutating func loadProfile(from profileData: NSProfile) {
        guard let store = profileData.store["default"] ?? profileData.store["Default"] else {
            return
        }

        self.units = profileData.units
        self.timezone = store.timezone
        self.defaultProfile = profileData.defaultProfile

        self.isfSchedule = store.sens.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value) }
        self.basalSchedule = store.basal.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value) }
        self.carbRatioSchedule = store.carbratio.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value) }
        if let overrides = store.overrides {
            self.overrides = overrides.map { Override(name: $0.name ?? "", targetRange: $0.targetRange ?? [], duration: $0.duration ?? 0, insulinNeedsScaleFactor: $0.insulinNeedsScaleFactor ?? 1.0, symbol: $0.symbol ?? "") }
        } else {
            self.overrides = []
        }
    }

    func currentISF() -> String? {
        if let isf = getCurrentValue(from: isfSchedule) {
            return Localizer.formatLocalDouble(isf, unit: self.units)
        }
        return nil
    }

    //TODO: Formatting
    func currentBasal() -> String? {
        if let basal = getCurrentValue(from: basalSchedule) {
            return formatValue(basal)
        }
        return nil
    }

    func currentCarbRatio() -> String? {
        if let carbRatio = getCurrentValue(from: carbRatioSchedule) {
            return Localizer.formatToLocalizedString(carbRatio)
        }
        return nil
    }

    private func getCurrentValue(from schedule: [TimeValue]) -> Double? {
        guard !schedule.isEmpty else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let currentTimeInSeconds = calendar.component(.hour, from: now) * 3600 +
        calendar.component(.minute, from: now) * 60 +
        calendar.component(.second, from: now)

        var lastValue: Double?
        for timeValue in schedule {
            if currentTimeInSeconds >= timeValue.timeAsSeconds {
                lastValue = timeValue.value
            } else {
                break
            }
        }
        return lastValue
    }

    private func formatValue(_ value: Double) -> String {
        if units == "mg/dL" {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    mutating func clear() {
        self.isfSchedule = []
        self.basalSchedule = []
        self.carbRatioSchedule = []
        self.overrides = []
        self.units = "mmol/L"
        self.timezone = "UTC"
        self.defaultProfile = ""
    }
}
