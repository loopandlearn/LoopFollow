// LoopFollow
// IOBAlarmEditor.swift
// Created by Jonas Björkert on 2025-05-19.

//
//  IOBAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-17.
//

import SwiftUI

struct IOBAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when insulin-on-board is high, or when several "
                    + "boluses in quick succession exceed the limits you set.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            // ── individual bolus size ──
            AlarmStepperSection(
                header: "Bolus Size",
                footer: "Only boluses equal to or larger than this are counted.",
                title: "Bolus ≥",
                range: 0.1 ... 20,
                step: 0.1,
                value: Binding(
                    get: { alarm.delta ?? 1.0 },
                    set: { alarm.delta = $0 }
                )
            )

            // ── number of boluses ──
            AlarmStepperSection(
                header: "Bolus Count",
                footer: "Number of qualifying boluses needed to trigger.",
                title: "Count ≥",
                range: 1 ... 10,
                step: 1,
                value: Binding(
                    get: { Double(alarm.monitoringWindow ?? 2) },
                    set: { alarm.monitoringWindow = Int($0) }
                )
            )

            // ── look-back window ──
            AlarmStepperSection(
                header: "Time Window",
                footer: "How far back to look for those boluses.",
                title: "Minutes",
                range: 5 ... 120,
                step: 5,
                value: Binding(
                    get: { Double(alarm.predictiveMinutes ?? 30) },
                    set: { alarm.predictiveMinutes = Int($0) }
                )
            )

            // ── absolute IOB limit ──
            AlarmStepperSection(
                header: "Total IOB",
                footer: "Alert if current IOB or total boluses reach this.",
                title: "IOB ≥",
                range: 1 ... 20,
                step: 0.5,
                value: Binding(
                    get: { alarm.threshold ?? 6 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm,
                               range: 1 ... 24,
                               step: 1) // snooze in hours
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
