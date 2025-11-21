// LoopFollow
// AGPGraphView.swift

import Charts
import SwiftUI

struct AGPGraphView: UIViewRepresentable {
    let agpData: [AGPDataPoint]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context _: Context) -> UIView {
        let containerView = NonInteractiveContainerView()
        containerView.backgroundColor = .systemBackground

        let chartView = LineChartView()
        chartView.rightAxis.enabled = true
        chartView.leftAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.rightAxis.drawGridLinesEnabled = false
        chartView.leftAxis.drawGridLinesEnabled = false
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.rightAxis.valueFormatter = ChartYMMOLValueFormatter()
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
        guard let chartView = containerView.subviews.first as? LineChartView else { return }
        guard !agpData.isEmpty else { return }
        var p5Entries: [ChartDataEntry] = []
        var p25Entries: [ChartDataEntry] = []
        var p50Entries: [ChartDataEntry] = []
        var p75Entries: [ChartDataEntry] = []
        var p95Entries: [ChartDataEntry] = []

        for point in agpData {
            let x = Double(point.timeOfDay) / 60.0
            p5Entries.append(ChartDataEntry(x: x, y: point.p5))
            p25Entries.append(ChartDataEntry(x: x, y: point.p25))
            p50Entries.append(ChartDataEntry(x: x, y: point.p50))
            p75Entries.append(ChartDataEntry(x: x, y: point.p75))
            p95Entries.append(ChartDataEntry(x: x, y: point.p95))
        }

        let sortedP5 = p5Entries.sorted { $0.x < $1.x }
        let sortedP25 = p25Entries.sorted { $0.x < $1.x }
        let sortedP50 = p50Entries.sorted { $0.x < $1.x }
        let sortedP75 = p75Entries.sorted { $0.x < $1.x }
        let sortedP95 = p95Entries.sorted { $0.x < $1.x }

        guard !sortedP5.isEmpty, !sortedP25.isEmpty, !sortedP50.isEmpty,
              !sortedP75.isEmpty, !sortedP95.isEmpty
        else {
            return
        }
        let p5DataSet = LineChartDataSet(entries: sortedP5, label: "5th")
        p5DataSet.colors = [NSUIColor.systemGray.withAlphaComponent(0.6)]
        p5DataSet.lineWidth = 1.5
        p5DataSet.drawCirclesEnabled = false
        p5DataSet.drawValuesEnabled = false
        p5DataSet.drawFilledEnabled = false
        p5DataSet.mode = .linear

        let p25DataSet = LineChartDataSet(entries: sortedP25, label: "25th")
        p25DataSet.colors = [NSUIColor.systemBlue.withAlphaComponent(0.7)]
        p25DataSet.lineWidth = 1.5
        p25DataSet.drawCirclesEnabled = false
        p25DataSet.drawValuesEnabled = false
        p25DataSet.drawFilledEnabled = false
        p25DataSet.mode = .linear

        let p50DataSet = LineChartDataSet(entries: sortedP50, label: "Median")
        p50DataSet.colors = [NSUIColor.systemBlue]
        p50DataSet.lineWidth = 3
        p50DataSet.drawCirclesEnabled = false
        p50DataSet.drawValuesEnabled = false
        p50DataSet.drawFilledEnabled = false
        p50DataSet.mode = .linear

        let p75DataSet = LineChartDataSet(entries: sortedP75, label: "75th")
        p75DataSet.colors = [NSUIColor.systemBlue.withAlphaComponent(0.7)]
        p75DataSet.lineWidth = 1.5
        p75DataSet.drawCirclesEnabled = false
        p75DataSet.drawValuesEnabled = false
        p75DataSet.drawFilledEnabled = false
        p75DataSet.mode = .linear

        let p95DataSet = LineChartDataSet(entries: sortedP95, label: "95th")
        p95DataSet.colors = [NSUIColor.systemGray.withAlphaComponent(0.6)]
        p95DataSet.lineWidth = 1.5
        p95DataSet.drawCirclesEnabled = false
        p95DataSet.drawValuesEnabled = false
        p95DataSet.drawFilledEnabled = false
        p95DataSet.mode = .linear
        let maxY = max(sortedP95.map { $0.y }.max() ?? 300, 300) + 10
        let hourMinY = min(sortedP5.map { $0.y }.min() ?? 0, 0) - 10

        var hourLines: [ChartDataEntry] = []
        for hour in 0 ... 24 {
            let x = Double(hour)
            hourLines.append(ChartDataEntry(x: x, y: hourMinY))
            hourLines.append(ChartDataEntry(x: x, y: maxY))
            if hour < 24 {
                hourLines.append(ChartDataEntry(x: x + 0.0001, y: hourMinY))
            }
        }

        let hourLinesDataSet = LineChartDataSet(entries: hourLines, label: "Hours")
        hourLinesDataSet.colors = [NSUIColor.label.withAlphaComponent(0.3)]
        hourLinesDataSet.lineWidth = 1
        hourLinesDataSet.drawCirclesEnabled = false
        hourLinesDataSet.drawValuesEnabled = false
        hourLinesDataSet.drawFilledEnabled = false

        let data = LineChartData()
        data.append(p5DataSet)
        data.append(p25DataSet)
        data.append(p50DataSet)
        data.append(p75DataSet)
        data.append(p95DataSet)
        data.append(hourLinesDataSet)

        chartView.data = data
        chartView.notifyDataSetChanged()
        chartView.setNeedsDisplay()
    }
}
