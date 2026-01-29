// LoopFollow
// GraphSettingsView.swift

import SwiftUI

struct GraphSettingsView: View {
    @ObservedObject private var showDots = Storage.shared.showDots
    @ObservedObject private var showLines = Storage.shared.showLines
    @ObservedObject private var showValues = Storage.shared.showValues
    @ObservedObject private var showAbsorption = Storage.shared.showAbsorption
    @ObservedObject private var showDIALines = Storage.shared.showDIALines
    @ObservedObject private var show30MinLine = Storage.shared.show30MinLine
    @ObservedObject private var show90MinLine = Storage.shared.show90MinLine
    @ObservedObject private var showMidnightLines = Storage.shared.showMidnightLines
    @ObservedObject private var smallGraphTreatments = Storage.shared.smallGraphTreatments

    @ObservedObject private var smallGraphHeight = Storage.shared.smallGraphHeight
    @ObservedObject private var predictionToLoad = Storage.shared.predictionToLoad
    @ObservedObject private var minBasalScale = Storage.shared.minBasalScale
    @ObservedObject private var minBGScale = Storage.shared.minBGScale
    @ObservedObject private var lowLine = Storage.shared.lowLine
    @ObservedObject private var highLine = Storage.shared.highLine
    @ObservedObject private var downloadDays = Storage.shared.downloadDays

    private var nightscoutEnabled: Bool {
        IsNightscoutEnabled()
    }

    var body: some View {
        NavigationView {
            Form {
                // ── Graph Display ────────────────────────────────────────────
                Section("Graph Display") {
                    Toggle("Display Dots", isOn: $showDots.value)
                        .onChange(of: showDots.value) { _ in markDirty() }

                    Toggle("Display Lines", isOn: $showLines.value)
                        .onChange(of: showLines.value) { _ in markDirty() }

                    if nightscoutEnabled {
                        Toggle("Show DIA Lines", isOn: $showDIALines.value)
                            .onChange(of: showDIALines.value) { _ in markDirty() }

                        Toggle("Show −30 min Line", isOn: $show30MinLine.value)
                            .onChange(of: show30MinLine.value) { _ in markDirty() }

                        Toggle("Show −90 min Line", isOn: $show90MinLine.value)
                            .onChange(of: show90MinLine.value) { _ in markDirty() }
                    }

                    Toggle("Show Midnight Lines", isOn: $showMidnightLines.value)
                        .onChange(of: showMidnightLines.value) { _ in markDirty() }
                }

                // ── Treatments ───────────────────────────────────────────────
                if nightscoutEnabled {
                    Section("Treatments") {
                        Toggle("Show Carb/Bolus Values", isOn: $showValues.value)
                        Toggle("Show Carb Absorption", isOn: $showAbsorption.value)
                        Toggle("Treatments on Small Graph",
                               isOn: $smallGraphTreatments.value)
                    }
                }

                // ── Small Graph ──────────────────────────────────────────────
                Section("Small Graph") {
                    SettingsStepperRow(
                        title: "Height",
                        range: 40 ... 80,
                        step: 5,
                        value: $smallGraphHeight.value,
                        format: { "\(Int($0)) pt" }
                    )
                    .onChange(of: smallGraphHeight.value) { _ in markDirty() }
                }

                // ── Prediction ───────────────────────────────────────────────
                if nightscoutEnabled {
                    Section("Prediction") {
                        SettingsStepperRow(
                            title: "Hours of Prediction",
                            range: 0 ... 6,
                            step: 0.25,
                            value: $predictionToLoad.value,
                            format: { "\($0.localized(maxFractionDigits: 2)) h" }
                        )
                    }
                }

                // ── Basal / BG scale ─────────────────────────────────────────
                if nightscoutEnabled {
                    Section("Basal / BG Scale") {
                        SettingsStepperRow(
                            title: "Min Basal",
                            range: 0.5 ... 20,
                            step: 0.5,
                            value: $minBasalScale.value,
                            format: { "\($0.localized(maxFractionDigits: 1)) U/h" }
                        )

                        BGPicker(
                            title: "Min BG Scale",
                            range: 40 ... 400,
                            value: $minBGScale.value
                        )
                        .onChange(of: minBGScale.value) { _ in markDirty() }
                    }
                }

                // ── Target lines ─────────────────────────────────────────────
                Section("Target Lines") {
                    BGPicker(title: "Low BG Line",
                             range: 40 ... 120,
                             value: $lowLine.value)
                        .onChange(of: lowLine.value) { _ in markDirty() }

                    BGPicker(title: "High BG Line",
                             range: 120 ... 400,
                             value: $highLine.value)
                        .onChange(of: highLine.value) { _ in markDirty() }
                }

                // ── History window ───────────────────────────────────────────
                if nightscoutEnabled {
                    Section("History") {
                        SettingsStepperRow(
                            title: "Show Days Back",
                            range: 1 ... 4,
                            step: 1,
                            value: $downloadDays.value,
                            format: { "\(Int($0)) d" }
                        )
                    }
                }
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("Graph Settings", displayMode: .inline)
    }

    /// Marks the chart as needing a redraw
    private func markDirty() {
        Observable.shared.chartSettingsChanged.value = true
    }
}
