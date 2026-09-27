// LoopFollow
// TRCCommandType.swift

import Foundation

enum TRCCommandType: String, Encodable {
    case bolus
    case tempTarget = "temp_target"
    case cancelTempTarget = "cancel_temp_target"
    case meal
    case startOverride = "start_override"
    case cancelOverride = "cancel_override"

    var displayName: String {
        switch self {
        case .bolus: return String(localized: "Bolus", comment: "Trio remote command")
        case .tempTarget: return String(localized: "Temp Target", comment: "Trio remote command")
        case .cancelTempTarget: return String(localized: "Cancel Temp Target", comment: "Trio remote command")
        case .meal: return String(localized: "Meal", comment: "Trio remote command")
        case .startOverride: return String(localized: "Start Override", comment: "Trio remote command")
        case .cancelOverride: return String(localized: "Cancel Override", comment: "Trio remote command")
        }
    }
}
