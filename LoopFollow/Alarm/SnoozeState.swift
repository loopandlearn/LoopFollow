// LoopFollow
// SnoozeState.swift
// Created by Jonas Björkert on 2025-04-26.

import Foundation

struct SnoozeState: Codable {
    var isSnoozed: Bool = false
    var snoozeUntil: Date?
}
