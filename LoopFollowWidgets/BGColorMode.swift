// LoopFollow
// BGColorMode.swift

import SwiftUI

/// BG coloring settings as mirrored into the App Group by `WatchConfig.saveToDefaults()`.
/// Complications run in their own process, so they read the values rather than
/// holding a `WatchConfig`.
struct BGColorSettings {
    let colorBGText: Bool
    let dynamicBGColor: Bool
    let low: Double
    let high: Double

    /// Defaults match the iPhone app's, so a complication rendered before the
    /// first config sync shows the same colors the phone would.
    static var current: BGColorSettings {
        let defaults = UserDefaults(suiteName: WidgetData.appGroupID)
        return BGColorSettings(
            colorBGText: defaults?.object(forKey: "colorBGText") as? Bool ?? true,
            dynamicBGColor: defaults?.object(forKey: "dynamicBGColor") as? Bool ?? false,
            low: defaults?.object(forKey: "bgColorLow") as? Double ?? 70.0,
            high: defaults?.object(forKey: "bgColorHigh") as? Double ?? 180.0
        )
    }

    func color(_ bg: Double) -> Color {
        guard colorBGText else { return .primary }
        guard dynamicBGColor else {
            if bg >= high { return .yellow }
            if bg <= low { return .red }
            return .green
        }
        return bgDynamicColor(bg)
    }
}
