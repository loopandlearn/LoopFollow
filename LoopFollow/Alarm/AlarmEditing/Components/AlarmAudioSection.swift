// LoopFollow
// AlarmAudioSection.swift

import SwiftUI
import UniformTypeIdentifiers

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

    @State private var customSounds: [CustomSound] = []
    @State private var showingImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(customSounds) { sound in
                            toneRow(tone: .custom(sound.id), label: sound.displayName)
                                .id(SoundFile.custom(sound.id))
                        }
                        .onDelete(perform: deleteCustomSounds)

                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import Sound…", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("Custom")
                    } footer: {
                        Text("Custom sounds stay on this device and aren't included in settings export.")
                    }

                    Section(header: Text("Built-in")) {
                        ForEach(SoundFile.allBuiltins) { tone in
                            toneRow(tone: tone, label: tone.displayName)
                                .id(tone)
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
                .onAppear {
                    reloadCustomSounds()
                    proxy.scrollTo(selected, anchor: .center)
                }
                .fileImporter(
                    isPresented: $showingImporter,
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: false
                ) { result in
                    handleImport(result)
                }
                .alert(
                    "Import Failed",
                    isPresented: Binding(
                        get: { importError != nil },
                        set: { if !$0 { importError = nil } }
                    ),
                    actions: { Button("OK", role: .cancel) { importError = nil } },
                    message: { Text(importError ?? "") }
                )
            }
        }
    }

    @ViewBuilder
    private func toneRow(tone: SoundFile, label: String) -> some View {
        Button {
            selected = tone
            AlarmSound.setSoundFile(tone)
            AlarmSound.stop()
            AlarmSound.playTest()
        } label: {
            HStack {
                Text(label)
                if tone == selected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private func reloadCustomSounds() {
        customSounds = CustomSoundStore.shared.list()
    }

    private func deleteCustomSounds(at offsets: IndexSet) {
        for index in offsets {
            let sound = customSounds[index]
            CustomSoundStore.shared.delete(sound.id)
        }
        reloadCustomSounds()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                let imported = try CustomSoundStore.shared.importFile(at: url)
                reloadCustomSounds()
                selected = .custom(imported.id)
                AlarmSound.setSoundFile(.custom(imported.id))
                AlarmSound.stop()
                AlarmSound.playTest()
            } catch {
                importError = error.localizedDescription
            }
        case let .failure(error):
            importError = error.localizedDescription
        }
    }
}
