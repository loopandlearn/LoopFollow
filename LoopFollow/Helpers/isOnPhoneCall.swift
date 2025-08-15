// LoopFollow
// isOnPhoneCall.swift

import CallKit
import Foundation

private let callObserver = CXCallObserver()

func isOnPhoneCall() -> Bool {
    return callObserver.calls.contains { !$0.hasEnded }
}
