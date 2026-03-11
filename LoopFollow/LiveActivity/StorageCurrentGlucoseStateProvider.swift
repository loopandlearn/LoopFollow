// LoopFollow
// StorageCurrentGlucoseStateProvider.swift

import Foundation

/// Reads the latest glucose state from LoopFollow’s existing single source of truth.
/// Provider remains source-agnostic (Nightscout vs Dexcom).
struct StorageCurrentGlucoseStateProvider: CurrentGlucoseStateProviding {
    var glucoseMgdl: Double? {
        guard
            let bg = Observable.shared.bg.value,
            bg > 0
        else {
            return nil
        }

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

    var iob: Double? {
        Storage.shared.lastIOB.value
    }

    var cob: Double? {
        Storage.shared.lastCOB.value
    }
}
