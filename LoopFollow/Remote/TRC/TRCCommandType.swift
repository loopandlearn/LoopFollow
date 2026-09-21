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
    case editMeal = "edit_meal"
    case deleteMeal = "delete_meal"

    /// Meal mutations get one APNs collapse id per command so two sends never collapse into one.
    var usesCommandIDAsCollapseID: Bool {
        self == .editMeal || self == .deleteMeal
    }

    var displayName: String {
        switch self {
        case .bolus: return "Bolus"
        case .tempTarget: return "Temp Target"
        case .cancelTempTarget: return "Cancel Temp Target"
        case .meal: return "Meal"
        case .startOverride: return "Start Override"
        case .cancelOverride: return "Cancel Override"
        case .editMeal: return "Edit Meal"
        case .deleteMeal: return "Delete Meal"
        }
    }
}
