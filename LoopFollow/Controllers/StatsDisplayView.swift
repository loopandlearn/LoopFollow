// LoopFollow
// StatsDisplayView.swift

import Charts
import SwiftUI

struct StatsDisplayView: View {
    @ObservedObject var model: StatsDisplayModel
    var onTap: (() -> Void)?

    var body: some View {
        HStack {
            StatsPieChartView(
                pieLow: model.pieLow,
                pieRange: model.pieRange,
                pieHigh: model.pieHigh
            )
            .frame(width: 100, height: 100)

            VStack(spacing: 10) {
                HStack {
                    statColumn(title: "Low:", value: model.lowPercent)
                    statColumn(title: "In Range:", value: model.inRangePercent)
                    statColumn(title: "High:", value: model.highPercent)
                }
                HStack {
                    statColumn(title: "Avg BG:", value: model.avgBG)
                    statColumn(title: model.estA1CTitle, value: model.estA1C)
                    statColumn(title: model.stdDevTitle, value: model.stdDev)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 100)
        .background(Color(.secondarySystemBackground))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack {
            Text(title)
                .font(.system(size: 15))
            Text(value)
                .font(.system(size: 15))
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatsPieChartView: UIViewRepresentable {
    var pieLow: Double
    var pieRange: Double
    var pieHigh: Double

    func makeUIView(context _: Context) -> PieChartView {
        let chart = PieChartView()
        chart.legend.enabled = false
        chart.drawEntryLabelsEnabled = false
        chart.drawHoleEnabled = false
        chart.rotationEnabled = false
        chart.isUserInteractionEnabled = false
        chart.backgroundColor = .clear
        return chart
    }

    func updateUIView(_ chart: PieChartView, context _: Context) {
        let entries = [
            PieChartDataEntry(value: max(pieLow, 0.1)),
            PieChartDataEntry(value: max(pieRange, 0.1)),
            PieChartDataEntry(value: max(pieHigh, 0.1)),
        ]

        let dataSet = PieChartDataSet(entries: entries, label: "")
        dataSet.drawIconsEnabled = false
        dataSet.sliceSpace = 0
        dataSet.drawValuesEnabled = false
        dataSet.valueLineWidth = 0
        dataSet.formLineWidth = 0
        dataSet.colors = [.systemRed, .systemGreen, .systemYellow]

        chart.data = PieChartData(dataSet: dataSet)
    }
}
