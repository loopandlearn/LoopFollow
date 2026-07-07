// LoopFollow
// InfoType.swift

import Foundation

enum InfoType: Int, CaseIterable, Codable {
    case iob, cob, basal, override, battery, pump, pumpBattery, sage, cage, recBolus, minMax, carbsToday, autosens, profile, target, isf, carbRatio, updated, tdd, iage

    var name: String {
        switch self {
        case .iob: return "IOB"
        case .cob: return "COB"
        case .basal: return "Basal"
        case .override: return "Override"
        case .battery: return "Battery"
        case .pump: return "Pump"
        case .pumpBattery: return "Pump Battery"
        case .sage: return "SAGE"
        case .cage: return "CAGE"
        case .recBolus: return "Rec. Bolus"
        case .minMax: return "Min/Max"
        case .carbsToday: return "Carbs today"
        case .autosens: return "Autosens"
        case .profile: return "Profile"
        case .target: return "Target"
        case .isf: return "ISF"
        case .carbRatio: return "CR"
        case .updated: return "Updated"
        case .tdd: return "TDD"
        case .iage: return "IAGE"
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
    /// pure-text rows are excluded for now.
    var isColorable: Bool {
        switch self {
        case .iob, .cob, .battery, .pumpBattery, .tdd, .recBolus, .carbsToday, .sage, .cage, .iage:
            return true
        default:
            return false
        }
    }

    /// The "concerning" direction for this metric, used by threshold coloring.
    /// Fixed per type: battery is bad when low, most others when high.
    var colorDirection: InfoColorDirection {
        switch self {
        case .battery, .pumpBattery:
            return .below
        default:
            return .above
        }
    }

    /// Unit shown next to the threshold fields so the user knows what to type.
    var colorUnitLabel: String? {
        switch self {
        case .battery, .pumpBattery:
            return "%"
        case .iob, .recBolus, .tdd:
            return "U"
        case .cob, .carbsToday:
            return "g"
        case .sage, .cage, .iage:
            return "days"
        default:
            return nil
        }
    }
}
