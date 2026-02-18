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

    /// Returns the appropriate text color based on the mode and BG value
    func textColor(for bgValue: Double, staticColor: UIColor) -> UIColor {
        switch self {
        case .staticColor:
            return staticColor
        case .dynamic:
            let highLine = Storage.shared.highLine.value
            let lowLine = Storage.shared.lowLine.value

            if bgValue >= highLine {
                return .systemYellow
            } else if bgValue <= lowLine {
                return .systemRed
            } else {
                return .systemGreen
            }
        }
    }

    /// Parses a BG string value to Double, handling locale-specific decimal separators
    static func parseBGValue(_ bgString: String) -> Double {
        // Replace comma with period to handle European locales
        let normalized = bgString.replacingOccurrences(of: ",", with: ".")
        // Keep only numbers and decimal point
        let numericString = normalized.filter { $0.isNumber || $0 == "." }
        return Double(numericString) ?? 0
    }
}
