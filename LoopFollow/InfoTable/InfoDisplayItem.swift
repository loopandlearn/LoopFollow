// LoopFollow
// InfoDisplayItem.swift

import SwiftUI

/// One configurable row in the Info Display: which info it shows, whether it is
/// visible, and its optional threshold-based coloring. The ordered array of
/// these replaces the old parallel `infoSort` / `infoVisible` storage.
struct InfoDisplayItem: Codable, Equatable, Identifiable {
    var type: InfoType
    var isVisible: Bool
    var coloring: InfoColoring

    var id: Int { type.rawValue }
}

extension Array where Element == InfoDisplayItem {
    func item(for type: InfoType) -> InfoDisplayItem? {
        first { $0.type == type }
    }

    func isVisible(_ type: InfoType) -> Bool {
        item(for: type)?.isVisible ?? false
    }
}

/// Which direction is "concerning" for a metric. Fixed per InfoType (battery is
/// bad when low, sensor age is bad when high) rather than user-configurable.
enum InfoColorDirection {
    case above // color as the value rises (e.g. SAGE, IOB)
    case below // color as the value falls (e.g. Battery, Pump)
}

/// What threshold coloring looks like for one InfoType: the concerning
/// direction, the unit shown next to the value, and the bounds the threshold
/// steppers move in. Only types that expose one of these can be colored.
struct InfoColorConfig {
    let direction: InfoColorDirection
    let unit: String
    let range: ClosedRange<Double>
    let step: Double
    let defaultWarning: Double
    let defaultUrgent: Double

    /// Decimals to show, derived from the step (0.5 → 1, 5 → 0).
    var fractionDigits: Int {
        step.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
    }
}

/// Per-row, opt-in color thresholds. Purely visual — never triggers an alarm.
struct InfoColoring: Codable, Equatable {
    var enabled: Bool = false
    var warning: Double? = nil // yellow
    var urgent: Double? = nil // red

    /// Resolves the color for a raw numeric value, given the metric's fixed
    /// direction. Returns `nil` only when coloring is off (callers map that to
    /// the default text color); when enabled, an in-range value reads green,
    /// mirroring the app's BG text coloring.
    func color(for value: Double, direction: InfoColorDirection) -> Color? {
        guard enabled else { return nil }
        switch direction {
        case .above:
            if let urgent, value >= urgent { return .red }
            if let warning, value >= warning { return .yellow }
        case .below:
            if let urgent, value <= urgent { return .red }
            if let warning, value <= warning { return .yellow }
        }
        return .green
    }
}
