//
//  HighBgAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-09.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct HighBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when your CGM glucose stays above the limit "
                + "you set below. Use Persistent if you want to ignore brief spikes."
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Threshold",
                footer: "The alarm becomes eligible once any reading is ≥ this value.",
                title: "BG",
                range: 120...350,
                value: Binding(
                    get: { alarm.threshold ?? 180 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmStepperSection(
                header: "Persistent High",
                footer: "How long glucose must remain above the threshold before the "
                + "alarm actually fires.  Set to 0 for an immediate alert.",
                title: "Persistent for",
                range: 0...120,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.persistentMinutes ?? 0) },
                    set: { alarm.persistentMinutes = Int($0) }
                )
            )

            AlarmAudioSection(alarm: $alarm)
            AlarmActiveSection(alarm: $alarm)
            AlarmSnoozeSection(
                alarm: $alarm,
                range: 10...120,
                step: 5
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
