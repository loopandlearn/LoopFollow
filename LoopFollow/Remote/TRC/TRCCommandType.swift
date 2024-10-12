//
//  TRCCommandType.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-10-05.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

enum TRCCommandType: String {
    case bolus = "bolus"
    case tempTarget = "temp_target"
    case cancelTempTarget = "cancel_temp_target"
    case meal = "meal"
    case startOverride = "start_override"
    case cancelOverride = "cancel_override"
}
