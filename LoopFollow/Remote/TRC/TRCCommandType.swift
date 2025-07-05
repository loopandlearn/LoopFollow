// LoopFollow
// TRCCommandType.swift
// Created by Jonas Björkert.

import Foundation

enum TRCCommandType: String {
    case bolus
    case tempTarget = "temp_target"
    case cancelTempTarget = "cancel_temp_target"
    case meal
    case startOverride = "start_override"
    case cancelOverride = "cancel_override"
}
