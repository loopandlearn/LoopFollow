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

            AlarmThresholdRow(
                title: "BG",
                range: 40...150,
                step: UserDefaultsRepository.getPreferredUnit() == .millimolesPerLiter ? 18.0 * 0.1 : 1.0,
                value: Binding(
                    get: { Double(alarm.threshold ?? 80) },
                    set: { alarm.threshold = Float($0) }
                )
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
