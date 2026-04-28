// LoopFollow
// LineChartWrapper.swift

import Charts
import SwiftUI

struct LineChartWrapper: UIViewRepresentable {
    let chartView: LineChartView

    func makeUIView(context _: Context) -> LineChartView {
        chartView
    }

    func updateUIView(_: LineChartView, context _: Context) {}
}
