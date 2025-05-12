//
//  BuildExpireAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct BuildExpireAlarmEditor: View {
    @Binding var alarm: Alarm

    var body: some View {
        Form {
            InfoBanner(
                text: "Sends a reminder before the looping-app build you’re following reaches its "
                + "TestFlight or Xcode expiry date. Currently only works for Trio 0.4 and later."
            )
            AlarmGeneralSection(alarm: $alarm)

            AlarmStepperSection(
                footer: "Choose how many days of notice you’d like before the build becomes unusable.",
                title: "Expires In",
                range: 1...14,
                step: 1,
                unitLabel: alarm.type.timeUnit.label,
                value: Binding(
                    get: { alarm.threshold ?? 1 },
                    set: { alarm.threshold = $0 }
                )
            )

            AlarmAudioSection(alarm: $alarm)
            AlarmActiveSection(alarm: $alarm)
            AlarmSnoozeSection(
                alarm: $alarm,
                range: 1...14,
                step: 1
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
