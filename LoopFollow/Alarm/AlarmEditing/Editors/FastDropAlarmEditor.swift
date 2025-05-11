//
//  FastDropAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct FastDropAlarmEditor: View {
    @Binding var alarm: Alarm

    @State private var useLimit: Bool = false

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when glucose readings drop rapidly. For example, three straight readings each falling by at least the amount you set. Optionally limit alerts to only fire below a certain BG level."
            )
            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Rate of Fall",
                footer: "How much the bg must fall to count as a “fast” drop.",
                title: "Drop per reading",
                range: 3...20,
                value: Binding(
                    get: { alarm.threshold ?? 4 },
                    set: { alarm.threshold = $0 }
                )
            )

            //TODO: In the migration script, use 1 value less than stored since we are switching from readings to drops
            AlarmStepperSection(
                header: "Consecutive Drops",
                footer: "Number of back-to-back drops—each meeting the rate above—required before an alert fires.",
                title: "Drops in a row",
                range: 1...3,
                step: 1,
                value: Binding(
                    get: { Double(alarm.monitoringWindow ?? 2) },
                    set: { alarm.monitoringWindow = Int($0) }
                )
            )
/*
            // ────────── BG LIMIT ───────────
            Section {
                Toggle("Only alert when below BG limit", isOn: $useLimit)
                    .onAppear {
                        useLimit = (alarm.threshold != nil)
                    }
                    .onChange(of: useLimit) { newValue in
                        if !newValue { alarm.threshold = nil }
                    }

                AlarmBGSection(
                    header: nil,
                    footer: "Ignored unless the toggle above is enabled.",
                    title: "Dropping below",
                    range: 40...300,
                    value: Binding(
                        get: { alarm.threshold ?? 70 },
                        set: { alarm.threshold = $0 }
                    )
                )
                .disabled(!useLimit)
                .opacity(useLimit ? 1 : 0.35)
            }   // Section
*/
            // ────────── SNOOZE  ────────────
            AlarmStepperSection(
                header: "Default Snooze",
                footer: "How long to silence this alert after you press Snooze.",
                title: "Default Snooze",
                range: 5...60,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.snoozeDuration) },
                    set: { alarm.snoozeDuration = Int($0) }
                )
            )

            // ────── SOUND / ACTIVE / UNTIL ──────
            AlarmAudioSection(alarm: $alarm)
            AlarmActiveSection(alarm: $alarm)
            AlarmSnoozedUntilSection(alarm: $alarm)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
