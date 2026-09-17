// LoopFollow
// BGColorMode.swift

import SwiftUI

extension WatchConfig {
    /// Resolves the display color for a BG value in mg/dL, mirroring what the
    /// iPhone app shows for the same reading and the same settings.
    ///
    /// With "Dynamic BG Color" off, this is the iPhone's threshold scheme.
    /// With it on, this is the continuous hue ramp in `bgDynamicColor`.
    func bgColor(_ bg: Double) -> Color {
        guard colorBGText else { return .primary }
        guard dynamicBGColor else {
            if bg >= bgColorHigh { return .yellow }
            if bg <= bgColorLow { return .red }
            return .green
        }
        return bgDynamicColor(bg)
    }
}
