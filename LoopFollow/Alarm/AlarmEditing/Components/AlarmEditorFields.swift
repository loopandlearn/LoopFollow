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

struct AlarmStepperSection: View {
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    let unitLabel: String
    @Binding var value: Double

    var body: some View {
        Section(
          header: Text(title),
          footer: Text("Set \(title), \(Int(range.lowerBound))–\(Int(range.upperBound)) \(unitLabel)")
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

import SwiftUI

struct AlarmAudioSection: View {
    @Binding var alarm: Alarm
    @State private var showingTonePicker = false

    var body: some View {
        Section(header: Text("Alert Sound")) {
            // ——— Tone Row ———
            Button {
                showingTonePicker = true
            } label: {
                HStack {
                    Text("Tone")
                    Spacer()
                    Text(alarm.soundFile.displayName)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingTonePicker) {
                NavigationView {
                    List {
                        ForEach(SoundFile.allCases) { tone in
                            Button {
                                alarm.soundFile = tone
                                // play test tone
                                AlarmSound.setSoundFile(str: tone.rawValue)
                                AlarmSound.stop()
                                AlarmSound.playTest()
                            } label: {
                                HStack {
                                    Text(tone.displayName)
                                    if alarm.soundFile == tone {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Choose Tone")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                AlarmSound.stop()
                                showingTonePicker = false
                            }
                        }
                    }
                }
            }

            // ——— Play / Repeat Toggles ———
            VStack(alignment: .leading, spacing: 8) {
                Text("Play")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $alarm.playSoundOption) {
                    ForEach(PlaySoundOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue.capitalized).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $alarm.repeatSoundOption) {
                    ForEach(RepeatSoundOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue.capitalized).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct AlarmActiveSection: View {
    @Binding var alarm: Alarm

    var body: some View {
        Section(header: Text("Active During")) {
            Picker("Active", selection: $alarm.activeOption) {
                Text("Always").tag(ActiveOption.always)
                Text("Day").tag(ActiveOption.day)
                Text("Night").tag(ActiveOption.night)
            }
            .pickerStyle(.segmented)
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


