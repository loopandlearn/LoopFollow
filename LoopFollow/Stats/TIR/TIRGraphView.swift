// LoopFollow
// TIRGraphView.swift

import Charts
import SwiftUI
import UIKit

struct TIRGraphView: UIViewRepresentable {
    let tirData: [TIRDataPoint]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context _: Context) -> UIView {
        let containerView = NonInteractiveContainerView()
        containerView.backgroundColor = .systemBackground

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
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.leftAxis.drawGridLinesEnabled = true
        chartView.leftAxis.gridLineDashLengths = [5, 5]
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.legend.enabled = false
        chartView.chartDescription.enabled = false
        chartView.isUserInteractionEnabled = false

        containerView.addSubview(chartView)
        chartView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: containerView.topAnchor),
            chartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            chartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    class Coordinator {}

    func updateUIView(_ containerView: UIView, context _: Context) {
        guard let chartView = containerView.subviews.first as? BarChartView else { return }
        guard !tirData.isEmpty else { return }

        var dataEntries: [BarChartDataEntry] = []
        var xAxisLabels: [String] = []

        for (index, point) in tirData.enumerated() {
            let entry = BarChartDataEntry(
                x: Double(index),
                yValues: [
                    point.veryLow,
                    point.low,
                    point.inRange,
                    point.high,
                    point.veryHigh,
                ]
            )
            dataEntries.append(entry)
            xAxisLabels.append(point.period.rawValue)
        }

        let dataSet = BarChartDataSet(entries: dataEntries, label: "Time in Range")
        dataSet.colors = [
            UIColor.systemRed.withAlphaComponent(0.8),
            UIColor.systemRed.withAlphaComponent(0.5),
            UIColor.systemGreen.withAlphaComponent(0.7),
            UIColor.systemYellow.withAlphaComponent(0.7),
            UIColor.systemOrange.withAlphaComponent(0.7),
        ]
        dataSet.stackLabels = ["Very Low", "Low", "In Range", "High", "Very High"]
        dataSet.drawValuesEnabled = false

        let data = BarChartData(dataSet: dataSet)
        data.barWidth = 0.6

        chartView.data = data

        chartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: xAxisLabels)
        chartView.xAxis.labelRotationAngle = 0
        chartView.xAxis.labelCount = xAxisLabels.count

        chartView.notifyDataSetChanged()
    }
}

class PercentageAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        return String(format: "%.0f%%", value)
    }
}
