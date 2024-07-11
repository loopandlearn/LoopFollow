//
//  InfoType.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-11.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

enum InfoType: Int, CaseIterable {
/*
    case iob = 0          // 0
    case cob = 1          // 1
    case basal = 2        // 2
    case override = 3     // 3
    case battery = 4      // 4
    case pump = 5         // 5
    case sage = 6         // 6
    case cage = 7         // 7
    case recBolus = 8     // 8
    case minMax = 9       // 9
    case carbsToday = 10  // 10
    case autosens = 11    // 11
    case profile = 12     // 12
  */
    case iob, cob, basal, override, battery, pump, sage, cage, recBolus, minMax, carbsToday, autosens, profile

    var name: String {
        switch self {
        case .iob: return "IOB"
        case .cob: return "COB"
        case .basal: return "Basal"
        case .override: return "Override"
        case .battery: return "Battery"
        case .pump: return "Pump"
        case .sage: return "SAGE"
        case .cage: return "CAGE"
        case .recBolus: return "Rec. Bolus"
        case .minMax: return "Min/Max"
        case .carbsToday: return "Carbs today"
        case .autosens: return "Autosens"
        case .profile: return "Profile"
        }
    }

    var defaultVisible: Bool {
        switch self {
        case .autosens, .profile:
            return false
        default:
            return true
        }
    }

    var sortOrder: Int {
        return self.rawValue
    }
}
