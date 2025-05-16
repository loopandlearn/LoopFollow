//
//  LowBgAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct LowBgAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(text: "Alerts when your current CGM value — "
                + "or any predicted value within the look-ahead window — "
                + "falls at or below the threshold you set.")

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Threshold",
                title: "BG",
                range: 40 ... 150,
                value: Binding(
                    get: { alarm.belowBG ?? 80 },
                    set: { alarm.belowBG = $0 }
                )
            )

            AlarmStepperSection(
                header: "PERSISTENCE",
                footer: "Glucose must stay below the threshold for this many minutes "
                    + "before the alert sounds. Set 0 to alert immediately.",
                title: "Persistent",
                range: 0 ... 120,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: Binding(
                    get: { Double(alarm.persistentMinutes ?? 0) },
                    set: { alarm.persistentMinutes = Int($0) }
                )
            )

            AlarmStepperSection(
                header: "PREDICTION",
                footer: "Look ahead this many minutes in Loop’s prediction; "
                    + "if any future value is at or below the threshold, "
                    + "you’ll be warned early. Set 0 to disable.",
                title: "Predictive",
                range: 0 ... 60,
                step: 5,
                unitLabel: alarm.type.snoozeTimeUnit.label,
                value: Binding(
                    get: { Double(alarm.predictiveMinutes ?? 0) },
                    set: { alarm.predictiveMinutes = Int($0) }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(
                alarm: $alarm,
                range: 5 ... 30,
                step: 5
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
