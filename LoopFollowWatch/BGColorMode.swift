// LoopFollow
// BGColorMode.swift

import SwiftUI

extension WatchConfig {
    /// Color for charted BG values in mg/dL: points, sparkline fills and the
    /// BG bar gradient. Always colored, matching `BGChartModel.colorFor` on the
    /// iPhone, which does not consult "Color BG Text" either.
    ///
    /// With "Dynamic BG Color" off, this is the iPhone's threshold scheme.
    /// With it on, this is the continuous hue ramp in `bgDynamicColor`.
    func bgPointColor(_ bg: Double) -> Color {
        guard dynamicBGColor else {
            if bg >= bgColorHigh { return .yellow }
            if bg <= bgColorLow { return .red }
            return .green
        }
        return bgDynamicColor(bg)
    }

    /// Color for the current-BG number, which honors "Color BG Text" the way
    /// the iPhone's main screen does.
    func bgTextColor(_ bg: Double) -> Color {
        colorBGText ? bgPointColor(bg) : .primary
    }
}
