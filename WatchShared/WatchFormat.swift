// LoopFollow
// WatchFormat.swift

import Foundation
import SwiftUI

/// Display formatting shared by the watch app and its complications. Values
/// arrive in mg/dL and are rendered in the unit chosen on the phone.
enum WatchFormat {
    /// A reading this old is shown struck through, as on the phone.
    static let staleAfter: TimeInterval = 12 * 60

    private static let mgdlFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.locale = .current
        return nf
    }()

    private static let oneDecimalFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        nf.locale = .current
        return nf
    }()

    private static let insulinFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        nf.locale = .current
        return nf
    }()

    static func glucose(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl:
            return mgdlFormatter.string(from: NSNumber(value: round(mgdl))) ?? "\(Int(round(mgdl)))"
        case .mmol:
            let mmol = GlucoseConversion.toMmol(mgdl)
            return oneDecimalFormatter.string(from: NSNumber(value: mmol)) ?? String(format: "%.1f", mmol)
        }
    }

    static func delta(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl:
            let v = Int(round(mgdl))
            if v == 0 { return "0" }
            return v > 0 ? "+\(v)" : "\(v)"
        case .mmol:
            let mmol = GlucoseConversion.toMmol(mgdl)
            let d = abs(mmol) < 0.05 ? 0.0 : mmol
            let formatted = oneDecimalFormatter.string(from: NSNumber(value: abs(d))) ?? String(format: "%.1f", abs(d))
            if d == 0 { return formatted }
            return d > 0 ? "+\(formatted)" : "-\(formatted)"
        }
    }

    static func trendArrow(_ trend: GlucoseSnapshot.Trend) -> String {
        switch trend {
        case .upFast: "↑↑"
        case .up: "↑"
        case .upSlight: "↗"
        case .flat: "→"
        case .downSlight: "↘︎"
        case .down: "↓"
        case .downFast: "↓↓"
        case .unknown: "–"
        }
    }

    static func insulin(_ units: Double) -> String {
        insulinFormatter.string(from: NSNumber(value: units)) ?? String(format: "%.2f", units)
    }

    static func iob(_ units: Double?) -> String {
        guard let units else { return "—" }
        return (oneDecimalFormatter.string(from: NSNumber(value: units)) ?? String(format: "%.1f", units)) + " U"
    }

    static func cob(_ grams: Double?) -> String {
        guard let grams else { return "—" }
        return "\(Int(round(grams))) g"
    }

    static func minutesAgo(_ date: Date, now: Date = Date()) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        return "\(minutes) min"
    }

    /// Phone semantics: yellow at or above high, red at or below low, green in
    /// range. White when the phone's "Color BG Text" setting is off.
    static func bgColor(_ mgdl: Double, lowMgdl: Double, highMgdl: Double, colored: Bool = true) -> Color {
        guard colored else { return .primary }
        if mgdl >= highMgdl { return .yellow }
        if mgdl <= lowMgdl { return .red }
        return .green
    }
}
