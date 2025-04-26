//
//  SnoozeState.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-03-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

struct SnoozeState: Codable {
    var isSnoozed: Bool = false
    var snoozeUntil: Date?
}
