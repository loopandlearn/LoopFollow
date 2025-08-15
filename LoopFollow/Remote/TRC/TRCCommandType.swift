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
}
