// LoopFollow
// BGDynamicColor.swift
//
// Maps a BG value (mg/dL) to a hue-based color.
// Red (hue 0°) at ≤55, Green (hue 120°) at 100, Purple (hue 270°) at ≥220.
// Interpolates linearly through the hue spectrum between those anchors.

import SwiftUI

/// Returns a hue-based color for a given BG value in mg/dL.
/// Low (≤55) = red, target (100) = green, high (≥220) = purple.
func bgDynamicColor(_ bg: Double) -> Color {
    let low = 55.0
    let target = 100.0
    let high = 220.0

    let redHue: CGFloat = 0.0 / 360.0
    let greenHue: CGFloat = 120.0 / 360.0
    let purpleHue: CGFloat = 270.0 / 360.0

    let hue: CGFloat
    if bg <= low {
        hue = redHue
    } else if bg >= high {
        hue = purpleHue
    } else if bg <= target {
        let ratio = CGFloat((bg - low) / (target - low))
        hue = redHue + ratio * (greenHue - redHue)
    } else {
        let ratio = CGFloat((bg - target) / (high - target))
        hue = greenHue + ratio * (purpleHue - greenHue)
    }

    return Color(hue: Double(hue), saturation: 0.6, brightness: 0.9)
}
