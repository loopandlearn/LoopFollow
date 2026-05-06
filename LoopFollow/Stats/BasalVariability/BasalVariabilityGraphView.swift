// LoopFollow
// BasalVariabilityGraphView.swift

import Charts
import SwiftUI
import UIKit

struct BasalVariabilityGraphView: UIViewRepresentable {
    let data: [BasalVariabilityDataPoint]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context _: Context) -> UIView {
        let container = NonInteractiveContainerView()
        container.backgroundColor = .systemBackground

        let chartView = BarChartView()
        chartView.backgroundColor = .systemBackground
        chartView.rightAxis.enabled = false
        chartView.leftAxis.enabled = true
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.granularity = 1.0
        chartView.leftAxis.axisMinimum = 0.0
        chartView.leftAxis.axisMaximum = 100.0
        chartView.leftAxis.valueFormatter = PercentageAxisValueFormatter()
        chartView.leftAxis.labelCount = 5
        chartView.leftAxis.drawGridLinesEnabled = true
        chartView.leftAxis.gridLineDashLengths = [5, 5]
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.legend.enabled = false
        chartView.chartDescription.enabled = false
        chartView.isUserInteractionEnabled = false

        container.addSubview(chartView)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: container.topAnchor),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    class Coordinator {}

    func updateUIView(_ containerView: UIView, context _: Context) {
        guard let chartView = containerView.subviews.first as? BarChartView else { return }
        guard !data.isEmpty else { return }

        var entries: [BarChartDataEntry] = []
        var labels: [String] = []

        for (index, point) in data.enumerated() {
            entries.append(BarChartDataEntry(
                x: Double(index),
                yValues: [point.veryBelow, point.below, point.atPlanned, point.above, point.veryAbove]
            ))
            labels.append(point.period.rawValue)
        }

        let dataSet = BarChartDataSet(entries: entries, label: "Basal Variability")
        dataSet.colors = [
            UIColor.systemBlue.withAlphaComponent(0.85),    // veryBelow
            UIColor.systemTeal.withAlphaComponent(0.65),    // below
            UIColor.systemGreen.withAlphaComponent(0.75),   // atPlanned
            UIColor.systemOrange.withAlphaComponent(0.65),  // above
            UIColor.systemRed.withAlphaComponent(0.75),     // veryAbove
        ]
        dataSet.stackLabels = ["< 50%", "50–75%", "75–125%", "125–150%", "> 150%"]
        dataSet.drawValuesEnabled = false

        let barData = BarChartData(dataSet: dataSet)
        barData.barWidth = 0.6
        chartView.data = barData
        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        chartView.xAxis.labelCount = labels.count
        chartView.notifyDataSetChanged()
    }
}
