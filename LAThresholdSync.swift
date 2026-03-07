//
//  LAThresholdSync.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-02-25.
//

import Foundation

/// Bridges LoopFollow's internal threshold settings
/// into the App Group for extension consumption.
///
/// This file belongs ONLY to the main app target.
enum LAThresholdSync {

    static func syncToAppGroup() {
        LAAppGroupSettings.setThresholds(
            lowMgdl: Storage.shared.lowLine.value,
            highMgdl: Storage.shared.highLine.value
        )
    }
}