//
//  AlarmAudioSection.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-12.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI

struct AlarmAudioSection: View {
    @Binding var alarm: Alarm
    @State private var showingTonePicker = false

    var body: some View {
        Section(header: Text("Alert Sound")) {
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
            .buttonStyle(.plain)
            .sheet(isPresented: $showingTonePicker) {
                TonePickerSheet(selected: $alarm.soundFile)
            }

            AlarmEnumMenuPicker(title: "Play", selection: $alarm.playSoundOption)
            AlarmEnumMenuPicker(title: "Repeat", selection: $alarm.repeatSoundOption)
        }
    }
}

struct AlarmEnumMenuPicker<E: CaseIterable & Hashable & DayNightDisplayable>: View {
    let title: String
    @Binding var selection: E

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(Array(E.allCases), id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }
    }
}

private struct TonePickerSheet: View {
    @Binding var selected: SoundFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(SoundFile.allCases) { tone in
                    Button {
                        selected = tone
                        AlarmSound.setSoundFile(str: tone.rawValue)
                        AlarmSound.stop()
                        AlarmSound.playTest()
                    } label: {
                        HStack {
                            Text(tone.displayName)
                            if tone == selected {
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
                        dismiss()
                    }
                }
            }
        }
    }
}
