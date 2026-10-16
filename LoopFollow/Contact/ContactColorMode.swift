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
            switch UnitSettingsStore.shared.glucoseBand(for: bgValue) {
            case .high: return .systemYellow
            case .low: return .systemRed
            case .inRange: return .systemGreen
            }
        }
    }
}
