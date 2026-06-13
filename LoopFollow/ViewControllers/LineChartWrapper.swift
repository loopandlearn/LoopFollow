// LoopFollow
// LineChartWrapper.swift

import Charts
import SwiftUI

struct LineChartWrapper: UIViewRepresentable {
    let chartView: LineChartView

    func makeUIView(context _: Context) -> LineChartView {
        chartView
    }

    func updateUIView(_: LineChartView, context _: Context) {
        // Intentionally empty. MainViewController owns the chart and calls
        // notifyDataSetChanged itself whenever it mutates the data; doing it
        // here too would redo that work on every unrelated SwiftUI re-render
        // of MainHomeView (e.g. the once-a-second minAgoText tick).
    }
}
