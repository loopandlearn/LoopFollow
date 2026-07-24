// LoopFollow
// RemainingTimeText.swift

import SwiftUI

/// Remaining time for an active override / temp target: a live countdown when
/// 2 hours or less remain, otherwise a static "29d 23h"-style duration —
/// a multi-day ticker reads poorly.
struct RemainingTimeText: View {
    let endAt: TimeInterval

    static let tickerMaxRemaining: TimeInterval = 2 * 3600

    private static let longFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.day, .hour, .minute]
        f.maximumUnitCount = 2
        return f
    }()

    var body: some View {
        let end = Date(timeIntervalSince1970: endAt)
        let remaining = end.timeIntervalSinceNow
        if remaining <= 0 {
            EmptyView()
        } else if remaining <= Self.tickerMaxRemaining {
            Text(timerInterval: Date() ... end, countsDown: true)
                .monospacedDigit()
        } else {
            Text(Self.longFormatter.string(from: remaining) ?? "")
        }
    }
}
