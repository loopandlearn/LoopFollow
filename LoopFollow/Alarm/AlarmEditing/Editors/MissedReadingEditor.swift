//
//  MissedReadingEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-09.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct MissedReadingEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(text: "The app notifies you when no CGM reading has been received for the time you choose below.", alarmType: alarm.type)

            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                footer: "Choose how long the app should wait before alerting.",
                title: "No reading for",
                range: 11...121,
                step: 5,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { alarm.threshold ?? 16 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmAudioSection(alarm: $alarm)

            AlarmActiveSection(alarm: $alarm)

            AlarmSnoozeSection(
                alarm: $alarm,
                range: 10...180,
                step: 5
            )

        }
        .navigationTitle(alarm.type.rawValue)
    }
}
