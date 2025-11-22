// LoopFollow
// AggregatedStatsView.swift

import SwiftUI
import UIKit

struct AggregatedStatsView: View {
    @ObservedObject var viewModel: AggregatedStatsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showGMI: Bool
    @State private var showStdDev: Bool
    @State private var selectedPeriod = 14
    @State private var isLoadingData = false

    init(viewModel: AggregatedStatsViewModel) {
        self.viewModel = viewModel
        _showGMI = State(initialValue: Storage.shared.showGMI.value)
        _showStdDev = State(initialValue: Storage.shared.showStdDev.value)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Statistics")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Picker("Period", selection: $selectedPeriod) {
                        Text("1 day").tag(1)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedPeriod) { newValue in
                        isLoadingData = true
                        viewModel.updatePeriod(newValue) {
                            isLoadingData = false
                        }
                    }
                }
                .padding(.top)

                if isLoadingData {
                    ProgressView("Loading data...")
                        .padding()
                }

                StatsGridView(
                    simpleStats: viewModel.simpleStats,
                    showGMI: $showGMI,
                    showStdDev: $showStdDev
                )
                .padding(.horizontal)

                AGPView(viewModel: viewModel.agpStats)
                    .padding(.horizontal)

                TIRView(viewModel: viewModel.tirStats)
                    .padding(.horizontal)

                GRIView(viewModel: viewModel.griStats)
                    .padding(.horizontal)
            }
            .padding(.bottom)
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Refresh") {
                    viewModel.calculateStats()
                }
            }
        }
        .onAppear {
            viewModel.dataService.ensureDataAvailable(
                onProgress: {},
                completion: {
                    viewModel.calculateStats()
                }
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String?
    let color: Color
    var isInteractive: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(color)

                    if let unit = unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            if isInteractive {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(8)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BasalComparisonCard: View {
    let programmed: Double?
    let actual: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Basal Comparison")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Text("Programmed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Actual Delivered")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                HStack {
                    VStack(spacing: 2) {
                        Text(formatBasal(programmed))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text("U")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 2) {
                        Text(formatBasal(actual))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("U")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if let prog = programmed, let act = actual, prog > 0 {
                    let diff = act - prog
                    let percentDiff = (diff / prog) * 100
                    HStack {
                        Spacer()
                        Text(String(format: "%.2f U (%.1f%%)", diff, percentDiff))
                            .font(.caption)
                            .foregroundColor(diff > 0 ? .red : .green)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatBasal(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        return String(format: "%.2f", value)
    }
}

struct StatsGridView: View {
    @ObservedObject var simpleStats: SimpleStatsViewModel
    @Binding var showGMI: Bool
    @Binding var showStdDev: Bool

    private var hasInsulinData: Bool {
        simpleStats.totalDailyDose != nil || simpleStats.avgBolus != nil || simpleStats.actualBasal != nil
    }

    private var hasCarbData: Bool {
        simpleStats.avgCarbs != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Button(action: {
                    showGMI.toggle()
                    Storage.shared.showGMI.value = showGMI
                }) {
                    StatCard(
                        title: showGMI ? "GMI" : "eHbA1c",
                        value: showGMI ? formatGMI(simpleStats.gmi) : formatEhbA1c(simpleStats.avgGlucose),
                        unit: showGMI ? "%" : (Storage.shared.units.value == "mg/dL" ? "%" : "mmol/mol"),
                        color: .blue,
                        isInteractive: true
                    )
                }
                .buttonStyle(PlainButtonStyle())

                StatCard(
                    title: "Avg Glucose",
                    value: formatGlucose(simpleStats.avgGlucose),
                    unit: Storage.shared.units.value,
                    color: .green
                )
            }

            HStack(spacing: 16) {
                Button(action: {
                    showStdDev.toggle()
                    Storage.shared.showStdDev.value = showStdDev
                }) {
                    StatCard(
                        title: showStdDev ? "Std Deviation" : "CV",
                        value: showStdDev ? formatStdDev(simpleStats.stdDeviation) : formatCV(simpleStats.coefficientOfVariation),
                        unit: showStdDev ? Storage.shared.units.value : "%",
                        color: .orange,
                        isInteractive: true
                    )
                }
                .buttonStyle(PlainButtonStyle())

                if hasInsulinData {
                    StatCard(
                        title: "Total Daily Dose",
                        value: formatInsulin(simpleStats.totalDailyDose),
                        unit: "U",
                        color: .red
                    )
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                }
            }

            if hasInsulinData || hasCarbData {
                HStack(spacing: 16) {
                    if hasInsulinData {
                        StatCard(
                            title: "Avg Bolus",
                            value: formatInsulin(simpleStats.avgBolus),
                            unit: "U/day",
                            color: .purple
                        )
                    }

                    if hasCarbData {
                        StatCard(
                            title: "Avg Carbs",
                            value: formatCarbs(simpleStats.avgCarbs),
                            unit: "g/day",
                            color: .orange
                        )
                    }
                }
            }

            if hasInsulinData {
                BasalComparisonCard(
                    programmed: simpleStats.programmedBasal,
                    actual: simpleStats.actualBasal
                )
            }
        }
    }

    private func formatGMI(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        return String(format: "%.1f", value)
    }

    private func formatEhbA1c(_ avgGlucose: Double?) -> String {
        guard let avgGlucose = avgGlucose else { return "---" }

        let avgGlucoseMgdL: Double
        if Storage.shared.units.value == "mg/dL" {
            avgGlucoseMgdL = avgGlucose
        } else {
            avgGlucoseMgdL = avgGlucose * 18.0182
        }

        let ehba1cPercent = (avgGlucoseMgdL + 46.7) / 28.7

        if Storage.shared.units.value == "mg/dL" {
            return String(format: "%.1f", ehba1cPercent)
        } else {
            let ehba1cMmolMol = (ehba1cPercent - 2.15) * 10.929
            return String(format: "%.0f", ehba1cMmolMol)
        }
    }

    private func formatGlucose(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        if Storage.shared.units.value == "mg/dL" {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatStdDev(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        if Storage.shared.units.value == "mg/dL" {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatInsulin(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        return String(format: "%.2f", value)
    }

    private func formatCarbs(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        return String(format: "%.0f", value)
    }

    private func formatCV(_ value: Double?) -> String {
        guard let value = value else { return "---" }
        return String(format: "%.1f", value)
    }
}
