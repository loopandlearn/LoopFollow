//
//  UUID+Identifiable.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
