// LoopFollow
// ContactColorMode.swift

import UIKit

enum ContactColorMode: String, Codable, CaseIterable {
    case staticColor = "Static"
    case dynamic = "Dynamic"

    var displayName: String {
        switch self {
        case .staticColor:
            return "Static"
        case .dynamic:
            return "Dynamic (BG Range)"
        }
    }

    /// Returns the appropriate text color based on the mode and BG value (in mg/dL).
    func textColor(for bgValue: Double, staticColor: UIColor) -> UIColor {
        switch self {
        case .staticColor:
            return staticColor
        case .dynamic:
            let normalize = UnitSettingsStore.shared.normalizeForColorComparison
            let normalizedBG = normalize(bgValue)
            let highLine = normalize(Storage.shared.highLine.value)
            let lowLine = normalize(Storage.shared.lowLine.value)

            if normalizedBG >= highLine {
                return .systemYellow
            } else if normalizedBG <= lowLine {
                return .systemRed
            } else {
                return .systemGreen
            }
        }
    }
}
