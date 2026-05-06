// WatchFormat.swift
// Philippe Achkar
// 2026-03-25

import Foundation

/// Formatting helpers for Watch complications and Watch app UI.
/// All glucose values in GlucoseSnapshot are stored in mg/dL; this module
/// converts to mmol/L for display when snapshot.unit == .mmol.
enum WatchFormat {

    // MARK: - Glucose

    static func glucose(_ s: GlucoseSnapshot) -> String {
        formatGlucoseValue(s.glucose, unit: s.unit)
    }

    static func delta(_ s: GlucoseSnapshot) -> String {
        switch s.unit {
        case .mgdl:
            let v = Int(round(s.delta))
            if v == 0 { return "0" }
            return v > 0 ? "+\(v)" : "\(v)"
        case .mmol:
            let mmol = GlucoseConversion.toMmol(s.delta)
            let d = abs(mmol) < 0.05 ? 0.0 : mmol
            if d == 0 { return "0.0" }
            let str = String(format: "%.1f", abs(d))
            return d > 0 ? "+\(str)" : "-\(str)"
        }
    }

    static func projected(_ s: GlucoseSnapshot) -> String {
        guard let v = s.projected else { return "—" }
        return formatGlucoseValue(v, unit: s.unit)
    }

    static func trendArrow(_ s: GlucoseSnapshot) -> String {
        switch s.trend {
        case .upFast:     return "↑↑"
        case .up:         return "↑"
        case .upSlight:   return "↗"
        case .flat:       return "→"
        case .downSlight: return "↘"
        case .down:       return "↓"
        case .downFast:   return "↓↓"
        case .unknown:    return "–"
        }
    }

    // MARK: - Time

    /// "Xm" from now, capped display at 99m
    static func minAgo(_ s: GlucoseSnapshot) -> String {
        let mins = Int(s.age / 60)
        return "\(min(mins, 99))m"
    }

    /// Time of last update formatted as "HH:mm"
    static func updateTime(_ s: GlucoseSnapshot) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: s.updatedAt)
    }

    static func currentTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    // MARK: - Secondary metrics

    static func iob(_ s: GlucoseSnapshot) -> String {
        guard let v = s.iob else { return "—" }
        return String(format: "%.1f", v)
    }

    static func cob(_ s: GlucoseSnapshot) -> String {
        guard let v = s.cob else { return "—" }
        return "\(Int(round(v)))"
    }

    static func battery(_ s: GlucoseSnapshot) -> String {
        guard let v = s.battery else { return "—" }
        return String(format: "%.0f%%", v)
    }

    static func pumpBattery(_ s: GlucoseSnapshot) -> String {
        guard let v = s.pumpBattery else { return "—" }
        return String(format: "%.0f%%", v)
    }

    static func pump(_ s: GlucoseSnapshot) -> String {
        guard let v = s.pumpReservoirU else { return "50+U" }
        return "\(Int(round(v)))U"
    }

    static func recBolus(_ s: GlucoseSnapshot) -> String {
        guard let v = s.recBolus else { return "—" }
        return String(format: "%.2fU", v)
    }

    static func autosens(_ s: GlucoseSnapshot) -> String {
        guard let v = s.autosens else { return "—" }
        return String(format: "%.0f%%", v * 100)
    }

    static func tdd(_ s: GlucoseSnapshot) -> String {
        guard let v = s.tdd else { return "—" }
        return String(format: "%.1fU", v)
    }

    static func basal(_ s: GlucoseSnapshot) -> String {
        s.basalRate.isEmpty ? "—" : s.basalRate
    }

    static func target(_ s: GlucoseSnapshot) -> String {
        guard let low = s.targetLowMgdl, low > 0 else { return "—" }
        let lowStr = formatGlucoseValue(low, unit: s.unit)
        if let high = s.targetHighMgdl, high > 0, abs(high - low) > 0.5 {
            return "\(lowStr)-\(formatGlucoseValue(high, unit: s.unit))"
        }
        return lowStr
    }

    static func isf(_ s: GlucoseSnapshot) -> String {
        guard let v = s.isfMgdlPerU, v > 0 else { return "—" }
        return formatGlucoseValue(v, unit: s.unit)
    }

    static func carbRatio(_ s: GlucoseSnapshot) -> String {
        guard let v = s.carbRatio, v > 0 else { return "—" }
        return String(format: "%.0fg", v)
    }

    static func carbsToday(_ s: GlucoseSnapshot) -> String {
        guard let v = s.carbsToday else { return "—" }
        return "\(Int(round(v)))g"
    }

    static func minMax(_ s: GlucoseSnapshot) -> String {
        guard let mn = s.minBgMgdl, let mx = s.maxBgMgdl else { return "—" }
        return "\(formatGlucoseValue(mn, unit: s.unit))/\(formatGlucoseValue(mx, unit: s.unit))"
    }

    static func age(insertTime: TimeInterval) -> String {
        guard insertTime > 0 else { return "—" }
        let secs = Date().timeIntervalSince1970 - insertTime
        let days = Int(secs / 86400)
        let hours = Int(secs.truncatingRemainder(dividingBy: 86400) / 3600)
        return days > 0 ? "\(days)d\(hours)h" : "\(hours)h"
    }

    static func override(_ s: GlucoseSnapshot) -> String { s.override ?? "—" }
    static func profileName(_ s: GlucoseSnapshot) -> String { s.profileName ?? "—" }

    // MARK: - Slot dispatch

    static func slotValue(option: LiveActivitySlotOption, snapshot s: GlucoseSnapshot) -> String {
        switch option {
        case .none:        return ""
        case .delta:       return delta(s)
        case .projectedBG: return projected(s)
        case .minMax:      return minMax(s)
        case .iob:         return iob(s)
        case .cob:         return cob(s)
        case .recBolus:    return recBolus(s)
        case .autosens:    return autosens(s)
        case .tdd:         return tdd(s)
        case .basal:       return basal(s)
        case .pump:        return pump(s)
        case .pumpBattery: return pumpBattery(s)
        case .battery:     return battery(s)
        case .target:      return target(s)
        case .isf:         return isf(s)
        case .carbRatio:   return carbRatio(s)
        case .sage:        return age(insertTime: s.sageInsertTime)
        case .cage:        return age(insertTime: s.cageInsertTime)
        case .iage:        return age(insertTime: s.iageInsertTime)
        case .carbsToday:  return carbsToday(s)
        case .override:    return override(s)
        case .profile:     return profileName(s)
        }
    }

    // MARK: - Private

    private static func formatGlucoseValue(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl:
            return "\(Int(round(mgdl)))"
        case .mmol:
            return String(format: "%.1f", GlucoseConversion.toMmol(mgdl))
        }
    }
}
