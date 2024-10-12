// ProfileManager.swift
// LoopFollow
// Created by Jonas Björkert on 2024-07-12.
// Copyright © 2024 Jon Fawcett. All rights reserved.

import Foundation
import HealthKit

struct ProfileManager {
    var isfSchedule: [TimeValue<HKQuantity>]
    var basalSchedule: [TimeValue<Double>]
    var carbRatioSchedule: [TimeValue<Double>]
    var targetLowSchedule: [TimeValue<HKQuantity>]
    var targetHighSchedule: [TimeValue<HKQuantity>]
    var overrides: [Override]
    var units: HKUnit
    var timezone: TimeZone
    var defaultProfile: String

    struct TimeValue<T> {
        let timeAsSeconds: Int
        let value: T
    }

    struct Override {
        let name: String
        let targetRange: [HKQuantity]
        let duration: Int
        let insulinNeedsScaleFactor: Double
        let symbol: String
    }

    init() {
        self.isfSchedule = []
        self.basalSchedule = []
        self.carbRatioSchedule = []
        self.targetLowSchedule = []
        self.targetHighSchedule = []
        self.overrides = []
        self.units = .millimolesPerLiter
        self.timezone = TimeZone.current
        self.defaultProfile = ""
    }

    mutating func loadProfile(from profileData: NSProfile) {
        guard let store = profileData.store[profileData.defaultProfile] else {
            return
        }

        self.units = store.units.lowercased() == "mg/dl" ? .milligramsPerDeciliter : .millimolesPerLiter
        self.defaultProfile = profileData.defaultProfile

        self.timezone = getTimeZone(from: store.timezone)

        self.isfSchedule = store.sens.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: HKQuantity(unit: self.units, doubleValue: $0.value)) }
        self.basalSchedule = store.basal.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value) }
        self.carbRatioSchedule = store.carbratio.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: $0.value) }
        self.targetLowSchedule = store.target_low?.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: HKQuantity(unit: self.units, doubleValue: $0.value)) } ?? []
        self.targetHighSchedule = store.target_high?.map { TimeValue(timeAsSeconds: Int($0.timeAsSeconds), value: HKQuantity(unit: self.units, doubleValue: $0.value)) } ?? []
        if let overrides = store.overrides {
            self.overrides = overrides.map { Override(name: $0.name ?? "", targetRange: $0.targetRange?.map { HKQuantity(unit: self.units, doubleValue: $0) } ?? [], duration: $0.duration ?? 0, insulinNeedsScaleFactor: $0.insulinNeedsScaleFactor ?? 1.0, symbol: $0.symbol ?? "") }
        } else {
            self.overrides = []
        }
    }

    func currentISF() -> HKQuantity? {
        return getCurrentValue(from: isfSchedule)
    }

    func currentBasal() -> String? {
        if let basal = getCurrentValue(from: basalSchedule) {
            return Localizer.formatToLocalizedString(basal, maxFractionDigits: 2, minFractionDigits: 0)
        }
        return nil
    }

    func currentCarbRatio() -> Double? {
        return getCurrentValue(from: carbRatioSchedule)
    }

    func currentTargetLow() -> HKQuantity? {
        return getCurrentValue(from: targetLowSchedule)
    }

    func currentTargetHigh() -> HKQuantity? {
        return getCurrentValue(from: targetHighSchedule)
    }

    private func getCurrentValue<T>(from schedule: [TimeValue<T>]) -> T? {
        guard !schedule.isEmpty else { return nil }

        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = self.timezone

        let currentTimeInSeconds = calendar.component(.hour, from: now) * 3600 +
        calendar.component(.minute, from: now) * 60 +
        calendar.component(.second, from: now)

        var lastValue: T?
        for timeValue in schedule {
            if currentTimeInSeconds >= timeValue.timeAsSeconds {
                lastValue = timeValue.value
            } else {
                break
            }
        }
        return lastValue
    }

    private func getTimeZone(from identifier: String) -> TimeZone {
        if let timeZone = TimeZone(identifier: identifier) {
            return timeZone
        }

        let adjustedIdentifier = identifier.replacingOccurrences(of: "ETC/", with: "Etc/")
        if let timeZone = TimeZone(identifier: adjustedIdentifier) {
            return timeZone
        }

        if identifier.uppercased().contains("GMT") {
            let components = identifier.uppercased().components(separatedBy: "GMT")
            if components.count > 1 {
                let offsetString = components[1]
                if let offsetHours = Int(offsetString) {
                    let correctedOffsetHours = -offsetHours
                    let secondsFromGMT = correctedOffsetHours * 3600
                    if let timeZone = TimeZone(secondsFromGMT: secondsFromGMT) {
                        return timeZone
                    }
                }
            }
        }

        return TimeZone.current
    }

    mutating func clear() {
        self.isfSchedule = []
        self.basalSchedule = []
        self.carbRatioSchedule = []
        self.targetLowSchedule = []
        self.targetHighSchedule = []
        self.overrides = []
        self.units = .millimolesPerLiter
        self.timezone = TimeZone.current
        self.defaultProfile = ""
    }
}
