// LoopFollow
// GRIRiskGridView.swift

import Charts
import SwiftUI

struct GRIRiskGridView: UIViewRepresentable {
    let hypoComponent: Double
    let hyperComponent: Double
    let gri: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context _: Context) -> UIView {
        let containerView = NonInteractiveContainerView()
        containerView.backgroundColor = .systemBackground

        let chartView = ScatterChartView()
        chartView.backgroundColor = .systemBackground
        chartView.rightAxis.enabled = false
        chartView.leftAxis.enabled = true
        chartView.legend.enabled = false
        chartView.chartDescription.enabled = false
        chartView.leftAxis.axisMinimum = 0
        chartView.leftAxis.axisMaximum = 60
        chartView.leftAxis.forceLabelsEnabled = true
        chartView.leftAxis.labelPosition = .outsideChart
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.axisMinimum = 0
        chartView.xAxis.axisMaximum = 30
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
        guard let chartView = containerView.subviews.first as? ScatterChartView else { return }

        chartView.data = nil

        var zoneAEntries: [ChartDataEntry] = []
        var zoneBEntries: [ChartDataEntry] = []
        var zoneCEntries: [ChartDataEntry] = []
        var zoneDEntries: [ChartDataEntry] = []
        var zoneEEntries: [ChartDataEntry] = []

        let step = 0.5
        for hypo in stride(from: 0.0, through: 30.0, by: step) {
            for hyper in stride(from: 0.0, through: 60.0, by: step) {
                let griValue = (3.0 * hypo) + (1.6 * hyper)

                guard griValue <= 100 else { continue }

                let entry = ChartDataEntry(x: hypo, y: hyper)

                if griValue <= 20 {
                    zoneAEntries.append(entry)
                } else if griValue <= 40 {
                    zoneBEntries.append(entry)
                } else if griValue <= 60 {
                    zoneCEntries.append(entry)
                } else if griValue <= 80 {
                    zoneDEntries.append(entry)
                } else {
                    zoneEEntries.append(entry)
                }
            }
        }

        let zoneADataSet = ScatterChartDataSet(entries: zoneAEntries, label: "Zone A")
        zoneADataSet.setColor(NSUIColor.systemGreen.withAlphaComponent(0.3))
        zoneADataSet.scatterShapeSize = 4
        zoneADataSet.drawValuesEnabled = false

        let zoneBDataSet = ScatterChartDataSet(entries: zoneBEntries, label: "Zone B")
        zoneBDataSet.setColor(NSUIColor.systemYellow.withAlphaComponent(0.3))
        zoneBDataSet.scatterShapeSize = 4
        zoneBDataSet.drawValuesEnabled = false

        let zoneCDataSet = ScatterChartDataSet(entries: zoneCEntries, label: "Zone C")
        zoneCDataSet.setColor(NSUIColor.systemOrange.withAlphaComponent(0.3))
        zoneCDataSet.scatterShapeSize = 4
        zoneCDataSet.drawValuesEnabled = false

        let zoneDDataSet = ScatterChartDataSet(entries: zoneDEntries, label: "Zone D")
        zoneDDataSet.setColor(NSUIColor.systemRed.withAlphaComponent(0.3))
        zoneDDataSet.scatterShapeSize = 4
        zoneDDataSet.drawValuesEnabled = false

        let zoneEDataSet = ScatterChartDataSet(entries: zoneEEntries, label: "Zone E")
        zoneEDataSet.setColor(NSUIColor.systemRed.withAlphaComponent(0.5))
        zoneEDataSet.scatterShapeSize = 4
        zoneEDataSet.drawValuesEnabled = false

        let currentPoint = ChartDataEntry(x: hypoComponent, y: hyperComponent)
        let currentDataSet = ScatterChartDataSet(entries: [currentPoint], label: "Current GRI")
        currentDataSet.setColor(NSUIColor.label)
        currentDataSet.scatterShapeSize = 12
        currentDataSet.setScatterShape(.circle)
        currentDataSet.drawValuesEnabled = false

        let data = ScatterChartData()
        data.append(zoneADataSet)
        data.append(zoneBDataSet)
        data.append(zoneCDataSet)
        data.append(zoneDDataSet)
        data.append(zoneEDataSet)
        data.append(currentDataSet)

        chartView.data = data

        chartView.xAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.0f", value)
        }
        chartView.leftAxis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            String(format: "%.0f", value)
        }

        chartView.xAxis.labelTextColor = .label
        chartView.leftAxis.labelTextColor = .label

        chartView.notifyDataSetChanged()
    }
}
