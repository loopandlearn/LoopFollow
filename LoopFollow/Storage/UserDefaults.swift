// LoopFollow
// UserDefaults.swift
// Created by Jon Fawcett on 2020-06-05.

import Foundation
import HealthKit
import UIKit

/*
 Legacy storage, we are moving away from this
 */

class UserDefaultsRepository {
    static let infoSort = UserDefaultsValue<[Int]>(key: "infoSort", default: InfoType.allCases.map { $0.sortOrder })
    static let infoVisible = UserDefaultsValue<[Bool]>(key: "infoVisible", default: InfoType.allCases.map { $0.defaultVisible })

    static func synchronizeInfoTypes() {
        var sortArray = infoSort.value
        var visibleArray = infoVisible.value

        // Current valid indices based on InfoType
        let currentValidIndices = InfoType.allCases.map { $0.rawValue }

        // Add missing indices to sortArray
        for index in currentValidIndices {
            if !sortArray.contains(index) {
                sortArray.append(index)
                // print("Added missing index \(index) to sortArray")
            }
        }

        // Remove deprecated indices
        sortArray = sortArray.filter { currentValidIndices.contains($0) }

        // Ensure visibleArray is updated with new entries
        if visibleArray.count < currentValidIndices.count {
            for i in visibleArray.count ..< currentValidIndices.count {
                visibleArray.append(InfoType(rawValue: i)?.defaultVisible ?? false)
                // print("Added default visibility for new index \(i)")
            }
        }

        // Trim excess elements if there are more than needed
        if visibleArray.count > currentValidIndices.count {
            visibleArray = Array(visibleArray.prefix(currentValidIndices.count))
            // print("Trimmed visibleArray to match current valid indices")
        }

        infoSort.value = sortArray
        infoVisible.value = visibleArray
    }

    static let hideInfoTable = UserDefaultsValue<Bool>(key: "hideInfoTable", default: false)

    // Nightscout Settings
    static let token = UserDefaultsValue<String>(key: "token", default: "")
    static let units = UserDefaultsValue<String>(key: "units", default: "mg/dL")

    static func getPreferredUnit() -> HKUnit {
        let unitString = units.value
        switch unitString {
        case "mmol/L":
            return .millimolesPerLiter
        default:
            return .milligramsPerDeciliter
        }
    }

    static func setPreferredUnit(_ unit: HKUnit) {
        var unitString = "mg/dL"
        if unit == .millimolesPerLiter {
            unitString = "mmol/L"
        }
        units.value = unitString
    }

    // Dexcom Share Settings
    static let shareUserName = UserDefaultsValue<String>(key: "shareUserName", default: "")
    static let sharePassword = UserDefaultsValue<String>(key: "sharePassword", default: "")
    static let shareServer = UserDefaultsValue<String>(key: "shareServer", default: "US")

    // Graph Settings
    static let chartScaleX = UserDefaultsValue<Float>(key: "chartScaleX", default: 18.0)

    // Deprecated, used to detect if backgroundRefresh was set to off. TODO: Remove in the beginning of 2026
    static let backgroundRefresh = UserDefaultsValue<Bool>(key: "backgroundRefresh", default: true)

    // Advanced Settings
    static let downloadTreatments = UserDefaultsValue<Bool>(key: "downloadTreatments", default: true)
    static let downloadPrediction = UserDefaultsValue<Bool>(key: "downloadPrediction", default: true)
    static let graphOtherTreatments = UserDefaultsValue<Bool>(key: "graphOtherTreatments", default: true)
    static let graphBasal = UserDefaultsValue<Bool>(key: "graphBasal", default: true)
    static let graphBolus = UserDefaultsValue<Bool>(key: "graphBolus", default: true)
    static let graphCarbs = UserDefaultsValue<Bool>(key: "graphCarbs", default: true)
    static let bgUpdateDelay = UserDefaultsValue<Int>(key: "bgUpdateDelay", default: 10)

    static let alertCageInsertTime = UserDefaultsValue<TimeInterval>(key: "alertCageInsertTime", default: 0)
    static let alertSageInsertTime = UserDefaultsValue<TimeInterval>(key: "alertSageInsertTime", default: 0)

    // What version is the cache valid for
    static let cachedForVersion = UserDefaultsValue<String?>(key: "cachedForVersion", default: nil)

    // Caching of latest version
    static let latestVersion = UserDefaultsValue<String?>(key: "latestVersion", default: nil)
    static let latestVersionChecked = UserDefaultsValue<Date?>(key: "latestVersionChecked", default: nil)

    // Caching of blacklisted version
    static let currentVersionBlackListed = UserDefaultsValue<Bool>(key: "currentVersionBlackListed", default: false)

    // Tracking notifications to manage frequency
    static let lastBlacklistNotificationShown = UserDefaultsValue<Date?>(key: "lastBlacklistNotificationShown", default: nil)
    static let lastVersionUpdateNotificationShown = UserDefaultsValue<Date?>(key: "lastVersionUpdateNotificationShown", default: nil)

    // Tracking the last time the expiration notification was shown
    static let lastExpirationNotificationShown = UserDefaultsValue<Date?>(key: "lastExpirationNotificationShown", default: nil)
}
