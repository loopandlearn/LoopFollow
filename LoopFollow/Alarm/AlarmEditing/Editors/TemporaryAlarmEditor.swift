//
//  TemporaryAlarmEditor.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-16.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct TemporaryAlarmEditor: View {
    @Binding var alarm: Alarm

    // Shared BG range
    private let bgRange: ClosedRange<Double> = 40 ... 300

    var body: some View {
        Form {
            InfoBanner(
                text: "This alert fires once when glucose crosses either of the limits you set below, and then disables itself.",
                alarmType: alarm.type
            )

            AlarmGeneralSection(alarm: $alarm)

            AlarmBGLimitSection(
                header: "Low Limit",
                footer: "Alert if BG is equal to or below this value.",
                toggleText: "Enable low limit",
                pickerTitle: "≤ BG",
                range: bgRange,
                value: $alarm.belowBG
            )

            AlarmBGLimitSection(
                header: "High Limit",
                footer: "Alert if BG is equal to or above this value.",
                toggleText: "Enable high limit",
                pickerTitle: "≥ BG",
                range: bgRange,
                value: $alarm.aboveBG
            )

            // Validation: ensure at least one limit is on
            if alarm.belowBG == nil && alarm.aboveBG == nil {
                Text("⚠️ Please enable at least one limit.")
                    .foregroundColor(.red)
            }

            AlarmActiveSection(alarm: $alarm)
            AlarmAudioSection(alarm: $alarm)
            AlarmSnoozeSection(alarm: $alarm, range: 5 ... 60, step: 5)
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
