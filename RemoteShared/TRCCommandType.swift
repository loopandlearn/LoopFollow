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
    case switchProfile = "switch_profile"
    case saveProfile = "save_profile"
    case deleteProfile = "delete_profile"
    case saveScheduledSwitches = "save_scheduled_switches"

    /// One collapse id per command.
    var usesCommandIDAsCollapseID: Bool {
        switch self {
        case .editMeal, .deleteMeal, .switchProfile, .saveProfile, .deleteProfile, .saveScheduledSwitches: return true
        default: return false
        }
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
        case .switchProfile: return "Switch Profile"
        case .saveProfile: return "Save Profile"
        case .deleteProfile: return "Delete Profile"
        case .saveScheduledSwitches: return "Save Scheduled Switches"
        }
    }
}
