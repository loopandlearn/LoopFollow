// LoopFollow
// RemoteType.swift
// Created by Jonas Björkert.

import Foundation

enum RemoteType: String, Codable {
    case none = "None"
    case nightscout = "Nightscout"
    case trc = "Trio Remote Control"
    case loopAPNS = "Loop APNS"
}
