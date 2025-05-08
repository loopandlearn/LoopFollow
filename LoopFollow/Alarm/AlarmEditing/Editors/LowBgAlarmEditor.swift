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
            AlarmGeneralSection(alarm: $alarm)

            AlarmBGSection(
                header: "Threshold",
                title: "BG",
                range: 40...150,
                value: Binding(
                    get: { alarm.threshold ?? 80 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmStepperSection(
                title: "Persistent",
                range: 0...120,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.persistentMinutes ?? 0) },
                    set: { alarm.persistentMinutes = Int($0) }
                )
            )

            AlarmStepperSection(
                title: "Predictive",
                //footer: include this manu minutes of prediction
                range: 0...60,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.predictiveMinutes ?? 0) },
                    set: { alarm.predictiveMinutes = Int($0) }
                )
            )

            AlarmStepperSection(
                title: "Default Snooze",
                range: 5...30,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { Double(alarm.snoozeDuration) },
                    set: { alarm.snoozeDuration = Int($0) }
                )
            )

            AlarmAudioSection(alarm: $alarm)
            AlarmActiveSection(alarm: $alarm)
            AlarmSnoozedUntilSection(alarm: $alarm)

        }
        .navigationTitle(alarm.type.rawValue)
    }
}
