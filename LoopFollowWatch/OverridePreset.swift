// LoopFollow
// OverridePreset.swift

import Foundation

struct OverridePreset: Identifiable {
    let id = UUID()
    let name: String
    let duration: Double?
    let percentage: Double?
    let target: Double?
}
