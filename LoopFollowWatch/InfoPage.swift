// LoopFollow
// InfoPage.swift

import SwiftUI

/// A compact table like the phone's info table; rows without data are hidden.
struct InfoPage: View {
    let state: WatchState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                rows
            }
            // Keeps the values clear of the page indicator.
            .padding(.trailing, 10)
        }
        .navigationTitle("Info")
    }

    @ViewBuilder
    private var rows: some View {
        if let s = state.snapshot {
            row("IOB", s.iob.map { WatchFormat.iob($0) })
            row("COB", s.cob.map { WatchFormat.cob($0) })
            row("Rec. Bolus", s.recBolus.map { "\(WatchFormat.insulin($0)) U" })
            row("Basal", s.basalRate.isEmpty ? nil : s.basalRate)
            row("Projected", s.projected.map { WatchFormat.glucose($0, unit: s.unit) })
            row("Min/Max", minMax(s))
            row("Override", s.override.map { name in name + remaining(s.overrideEndAt) })
            row("Temp Target", s.tempTargetMgdl.map { WatchFormat.glucose($0, unit: s.unit) + remaining(s.tempTargetEndAt) })
            row("Target", target(s))
            row("ISF", s.isfMgdlPerU.map { WatchFormat.glucose($0, unit: s.unit) })
            row("CR", s.carbRatio.map { "\(WatchFormat.insulin($0)) g" })
            row("Autosens", s.autosens.map { "\(Int(round($0 * 100))) %" })
            row("TDD", s.tdd.map { "\(WatchFormat.insulin($0)) U" })
            row("Carbs today", s.carbsToday.map { "\(Int(round($0))) g" })
            row("Pump", s.pumpReservoirU.map { "\(WatchFormat.insulin($0)) U" })
            row("Pump Battery", s.pumpBattery.map { "\(Int(round($0))) %" })
            row("Battery", s.battery.map { "\(Int(round($0))) %" })
            row("SAGE", age(s.sageInsertTime))
            row("CAGE", age(s.cageInsertTime))
            row("IAGE", age(s.iageInsertTime))
            row("Profile", s.profileName)
        }
        row("Last Loop", state.lastLoopAt.map { WatchFormat.minutesAgo($0) + " ago" })
        if let sensor = state.snapshot?.cgmSensorState {
            Text(sensor)
                .font(.footnote)
                .foregroundStyle(.orange)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
            .font(.footnote)
            .padding(.vertical, 3)
            Divider()
        }
    }

    private func minMax(_ s: GlucoseSnapshot) -> String? {
        guard let low = s.minBgMgdl, let high = s.maxBgMgdl else { return nil }
        return "\(WatchFormat.glucose(low, unit: s.unit))/\(WatchFormat.glucose(high, unit: s.unit))"
    }

    private func target(_ s: GlucoseSnapshot) -> String? {
        guard let low = s.targetLowMgdl else { return nil }
        let lowText = WatchFormat.glucose(low, unit: s.unit)
        guard let high = s.targetHighMgdl, round(high) != round(low) else { return lowText }
        return "\(lowText)–\(WatchFormat.glucose(high, unit: s.unit))"
    }

    private func remaining(_ endAt: TimeInterval?) -> String {
        guard let endAt else { return "" }
        let minutes = Int((endAt - Date().timeIntervalSince1970) / 60)
        guard minutes > 0 else { return "" }
        return minutes >= 60 ? " (\(minutes / 60) h \(minutes % 60) min)" : " (\(minutes) min)"
    }

    private func age(_ insertTime: TimeInterval) -> String? {
        guard insertTime > 0 else { return nil }
        let hours = Int((Date().timeIntervalSince1970 - insertTime) / 3600)
        guard hours >= 0 else { return nil }
        return "\(hours / 24)d \(hours % 24)h"
    }
}
