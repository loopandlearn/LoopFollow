// LoopFollow
// isOnPhoneCall.swift
// Created by Jonas Björkert on 2025-05-03.

import CallKit
import Foundation

private let callObserver = CXCallObserver()

func isOnPhoneCall() -> Bool {
    return callObserver.calls.contains { !$0.hasEnded }
}
