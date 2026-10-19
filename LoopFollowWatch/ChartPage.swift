// LoopFollow
// ChartPage.swift

import SwiftUI

/// The full chart on its own page.
struct ChartPage: View {
    let state: WatchState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            WatchChartView(state: state, now: context.date)
                // Keeps the axis labels clear of the page indicator.
                .padding(.trailing, 10)
        }
    }
}
