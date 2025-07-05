// LoopFollow
// SnoozeState.swift
// Created by Jonas Björkert.

import Foundation

struct SnoozeState: Codable {
    var isSnoozed: Bool = false
    var snoozeUntil: Date?
}
