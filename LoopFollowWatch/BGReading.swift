// LoopFollow
// BGReading.swift

import Foundation
import SwiftUI

struct BGReading {
    let bgValue: Int // raw mg/dL
    let direction: String // trend arrow
    let timestamp: Date
    let delta: Int? // difference from previous reading in mg/dL

    func bgText(units: String) -> String {
        if units == "mmol/L" {
            let mmol = Double(bgValue) * 0.0555
            return String(format: "%.1f", mmol)
        }
        return "\(bgValue)"
    }

    func deltaText(units: String) -> String {
        guard let delta = delta else { return "" }
        let prefix = delta >= 0 ? "+" : ""
        if units == "mmol/L" {
            let mmol = Double(delta) * 0.0555
            return String(format: "%@%.1f", prefix, mmol)
        }
        return "\(prefix)\(delta)"
    }

    func bgColor(lowLine: Double, highLine: Double) -> Color {
        let bg = Double(bgValue)
        if bg <= lowLine {
            return .red
        } else if bg >= highLine {
            return .yellow
        }
        return .green
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 720 // 12 minutes
    }

    var minAgoText: String {
        let totalSeconds = Int(Date().timeIntervalSince(timestamp))
        if totalSeconds < 5 { return "now" }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)m \(seconds)s"
    }

    static func directionArrow(_ direction: String) -> String {
        switch direction {
        case "Flat": return "\u{2192}"
        case "DoubleUp": return "\u{2191}\u{2191}"
        case "SingleUp": return "\u{2191}"
        case "FortyFiveUp": return "\u{2197}"
        case "FortyFiveDown": return "\u{2198}\u{FE0E}"
        case "SingleDown": return "\u{2193}"
        case "DoubleDown": return "\u{2193}\u{2193}"
        case "NONE", "NOT COMPUTABLE", "RATE OUT OF RANGE", "None", "":
            return "-"
        default: return "-"
        }
    }
}
