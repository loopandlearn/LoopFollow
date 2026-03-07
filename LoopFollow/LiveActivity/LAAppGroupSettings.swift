//
//  LAAppGroupSettings.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-24.
//

import Foundation

/// Minimal App Group settings needed by the Live Activity UI.
///
/// We keep this separate from Storage.shared to avoid target-coupling and
/// ensure the widget extension reads the same values as the app.
enum LAAppGroupSettings {

    private enum Keys {
        static let lowLineMgdl = "la.lowLine.mgdl"
        static let highLineMgdl = "la.highLine.mgdl"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupID.current())
    }

    // MARK: - Write (App)

    static func setThresholds(lowMgdl: Double, highMgdl: Double) {
        defaults?.set(lowMgdl, forKey: Keys.lowLineMgdl)
        defaults?.set(highMgdl, forKey: Keys.highLineMgdl)
    }

    // MARK: - Read (Extension)

    static func thresholdsMgdl(fallbackLow: Double = 70, fallbackHigh: Double = 180) -> (low: Double, high: Double) {
        let low = defaults?.object(forKey: Keys.lowLineMgdl) as? Double ?? fallbackLow
        let high = defaults?.object(forKey: Keys.highLineMgdl) as? Double ?? fallbackHigh
        return (low, high)
    }
}