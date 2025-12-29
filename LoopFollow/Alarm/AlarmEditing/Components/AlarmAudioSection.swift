// LoopFollow
// AlarmAudioSection.swift

import SwiftUI

struct AlarmAudioSection: View {
    @Binding var alarm: Alarm
    var hideRepeat: Bool = false
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

            AlarmEnumMenuPicker(
                title: "Play",
                selection: $alarm.playSoundOption,
                allowed: PlaySoundOption.allowed(for: alarm.activeOption)
            )

            if !hideRepeat {
                AlarmEnumMenuPicker(
                    title: "Repeat",
                    selection: $alarm.repeatSoundOption,
                    allowed: RepeatSoundOption.allowed(for: alarm.activeOption)
                )
            }

            Stepper(
                value: $alarm.soundDelay,
                in: 0 ... 60,
                step: 5
            ) {
                HStack {
                    Text("Delay Between Sounds")
                    Spacer()
                    if alarm.soundDelay == 0 {
                        Text("Off")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(alarm.soundDelay) sec")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }.onChange(of: alarm.activeOption) { newActive in
            let playAllowed = PlaySoundOption.allowed(for: newActive)
            if !playAllowed.contains(alarm.playSoundOption) {
                alarm.playSoundOption = playAllowed.last!
            }

            let repeatAllowed = RepeatSoundOption.allowed(for: newActive)
            if !repeatAllowed.contains(alarm.repeatSoundOption) {
                alarm.repeatSoundOption = repeatAllowed.last!
            }
        }
    }
}

struct AlarmEnumMenuPicker<E: CaseIterable & Hashable & DayNightDisplayable>: View {
    let title: String
    @Binding var selection: E
    var allowed: [E]

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(allowed, id: \.self) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            // if the current selection became invalid, snap to the first allowed
            .onAppear { validate() }
            .onChange(of: allowed) { _ in validate() }
        }
    }

    private func validate() {
        if !allowed.contains(selection), let first = allowed.first {
            selection = first
        }
    }
}

extension AlarmEnumMenuPicker where E: CaseIterable {
    init(title: String, selection: Binding<E>) {
        self.title = title
        _selection = selection
        allowed = Array(E.allCases)
    }
}

private struct TonePickerSheet: View {
    @Binding var selected: SoundFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
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
                        .id(tone)
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
                .onAppear {
                    proxy.scrollTo(selected, anchor: .center)
                }
            }
        }
    }
}
