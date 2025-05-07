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
                title: "BG",
                range: 40...150,
                value: Binding(
                    get: { alarm.threshold ?? 80 },
                    set: { alarm.threshold = $0 }
                )
            )
        }
        .navigationTitle(alarm.type.rawValue)
    }
}
