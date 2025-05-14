//
//  isOnPhoneCall.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-26.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import CallKit
import Foundation

private let callObserver = CXCallObserver()

func isOnPhoneCall() -> Bool {
    return callObserver.calls.contains { !$0.hasEnded }
}
