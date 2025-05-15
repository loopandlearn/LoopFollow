//
//  RecBolusAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct RecBolusAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Alerts when the recommended bolus equals or exceeds the " +
                    "threshold you set below.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                header: "Threshold",
                footer: "Alert when recommended bolus ≥ this value.",
                title: "Units",
                range: 0.1 ... 50,
                step: 0.1,
                value: Binding(
                    get: { alarm.threshold ?? 1.0 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm, range: 5 ... 60, step: 5)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
