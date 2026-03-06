// BareBonesAttributes.swift
// Philippe Achkar
// 2026-03-06
//
// Shared between the main app target AND the extension target.
// Add this file to both targets in Xcode.

import ActivityKit
import Foundation

struct BareBonesAttributes: ActivityAttributes {
public struct ContentState: Codable, Hashable {
/// A simple counter that changes every update.
/// If iOS re-renders when this changes, the pipeline works.
var counter: Int
/// Human-readable label so we can see updates on screen.
var label: String
}


/// Static attribute — required by ActivityAttributes.
let name: String


}