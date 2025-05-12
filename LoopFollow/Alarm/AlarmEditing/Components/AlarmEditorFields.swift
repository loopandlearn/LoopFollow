//
//  AlarmEditorFields.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct AlarmGeneralSection: View {
    @Binding var alarm: Alarm

    var body: some View {
        Section(header: Text("General")) {
            HStack {
                Text("Name")
                TextField("Alarm Name", text: $alarm.name)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
            }
            Toggle("Enabled", isOn: $alarm.isEnabled)
        }
    }
}

struct AlarmSnoozeSection: View {
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let unitLabel: String
    @Binding var value: Double

    var body: some View {
        Section(
          header: Text(title),
          footer: Text("How long to snooze after firing \(Int(range.lowerBound))–\(Int(range.upperBound)) \(unitLabel)")
        ) {
            Stepper(
                "\(title): \(Int(value)) \(unitLabel)",
                value: $value,
                in: range,
                step: step
            )
        }
    }
}

struct AlarmSnoozedUntilSection: View {
    @Binding var alarm: Alarm

    private var isSnoozed: Binding<Bool> {
        Binding(
            get: {
                if let until = alarm.snoozedUntil, until > Date() {
                    return true
                }
                return false
            },
            set: { on in
                if on {
                    // keep existing future snooze or set default ahead
                    if let until = alarm.snoozedUntil, until > Date() {
                        alarm.snoozedUntil = until
                    } else {
                        let secs = alarm.type.timeUnit.seconds
                        alarm.snoozedUntil = Date().addingTimeInterval(Double(alarm.snoozeDuration) * secs)
                    }
                } else {
                    alarm.snoozedUntil = nil
                }
            }
        )
    }

    var body: some View {
        Section(header: Text("Snoozed Until")) {
            Toggle("Snoozed", isOn: isSnoozed)
            if isSnoozed.wrappedValue, let until = alarm.snoozedUntil {
                DatePicker("Until", selection: Binding(
                    get: { until },
                    set: { alarm.snoozedUntil = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
            }
        }
    }
}


