//
//  RemoteType.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-18.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

enum RemoteType: String, Codable {
    case none = "None"
    case nightscout = "Nightscout"
    case trc = "Trio Remote Control"
}
