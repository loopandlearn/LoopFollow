// LoopFollow
// InfoType.swift

import Foundation

enum InfoType: Int, CaseIterable, Codable {
    case iob, cob, basal, override, battery, pump, pumpBattery, sage, cage, recBolus, minMax, carbsToday, autosens, profile, target, isf, carbRatio, updated, tdd, iage, dbSize

    var name: String {
        switch self {
        case .iob: return String(localized: "IOB", comment: "Info table row")
        case .cob: return String(localized: "COB", comment: "Info table row")
        case .basal: return String(localized: "Basal", comment: "Info table row")
        case .override: return String(localized: "Override", comment: "Info table row")
        case .battery: return String(localized: "Battery", comment: "Info table row")
        case .pump: return String(localized: "Pump", comment: "Info table row")
        case .pumpBattery: return String(localized: "Pump Battery", comment: "Info table row")
        case .sage: return String(localized: "SAGE", comment: "Info table row")
        case .cage: return String(localized: "CAGE", comment: "Info table row")
        case .recBolus: return String(localized: "Rec. Bolus", comment: "Info table row")
        case .minMax: return String(localized: "Min/Max", comment: "Info table row")
        case .carbsToday: return String(localized: "Carbs today", comment: "Info table row")
        case .autosens: return String(localized: "Autosens", comment: "Info table row")
        case .profile: return String(localized: "Profile", comment: "Info table row")
        case .target: return String(localized: "Target", comment: "Info table row")
        case .isf: return String(localized: "ISF", comment: "Info table row")
        case .carbRatio: return String(localized: "CR", comment: "Info table row")
        case .updated: return String(localized: "Updated", comment: "Info table row")
        case .tdd: return String(localized: "TDD", comment: "Info table row")
        case .iage: return String(localized: "IAGE", comment: "Info table row")
        case .dbSize: return String(localized: "DB Size", comment: "Info table row")
        }
    }

    var defaultVisible: Bool {
        switch self {
        case .iob, .cob, .basal, .override, .battery, .pump, .sage, .cage, .recBolus, .minMax, .carbsToday:
            return true
        default:
            return false
        }
    }

    var sortOrder: Int {
        return rawValue
    }

    /// Rows that carry a single numeric value can offer color thresholds.
    /// Combined rows (basal, min/max), BG-unit rows (target, ISF, CR) and
    /// pure-text rows have no config and are therefore not colorable.
    /// Steps mirror the equivalent alarm editors, so a value that takes decimals
    /// in an alarm takes decimals here too.
    var colorConfig: InfoColorConfig? {
        switch self {
        case .iob:
            return InfoColorConfig(direction: .above, unit: "U", range: 0 ... 20, step: 0.5, defaultWarning: 3, defaultUrgent: 5)
        case .cob:
            return InfoColorConfig(direction: .above, unit: "g", range: 0 ... 200, step: 1, defaultWarning: 30, defaultUrgent: 60)
        case .battery, .pumpBattery:
            return InfoColorConfig(direction: .below, unit: "%", range: 0 ... 100, step: 5, defaultWarning: 30, defaultUrgent: 15)
        case .pump:
            return InfoColorConfig(direction: .below, unit: "U", range: 0 ... 50, step: 1, defaultWarning: 20, defaultUrgent: 10)
        case .tdd:
            return InfoColorConfig(direction: .above, unit: "U", range: 0 ... 200, step: 1, defaultWarning: 60, defaultUrgent: 80)
        case .recBolus:
            return InfoColorConfig(direction: .above, unit: "U", range: 0 ... 20, step: 0.1, defaultWarning: 1, defaultUrgent: 2)
        case .carbsToday:
            return InfoColorConfig(direction: .above, unit: "g", range: 0 ... 500, step: 5, defaultWarning: 150, defaultUrgent: 250)
        case .sage:
            return InfoColorConfig(direction: .above, unit: "days", range: 0.5 ... 15, step: 0.5, defaultWarning: 9, defaultUrgent: 9.5)
        case .cage, .iage:
            return InfoColorConfig(direction: .above, unit: "days", range: 0.5 ... 10, step: 0.5, defaultWarning: 2.5, defaultUrgent: 3)
        default:
            return nil
        }
    }

    var isColorable: Bool { colorConfig != nil }
}
