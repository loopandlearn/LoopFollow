//
//  ContactColorOption.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-02-22.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import UIKit

enum ContactColorOption: String, CaseIterable {
    case red, blue, cyan, green, yellow, orange, purple, white, black

    var uiColor: UIColor {
        switch self {
        case .red:    return .red
        case .blue:   return .blue
        case .cyan:   return .cyan
        case .green:  return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .white:  return .white
        case .black:  return .black
        }
    }
}
