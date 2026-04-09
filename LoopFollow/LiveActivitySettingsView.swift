// LoopFollow
// LiveActivitySettingsView.swift

import SwiftUI

struct LiveActivitySettingsView: View {
    @State private var laEnabled: Bool = Storage.shared.laEnabled.value
    @State private var restartConfirmed = false
    @State private var slots: [LiveActivitySlotOption] = LAAppGroupSettings.slots()
    @State private var smallWidgetSlot: LiveActivitySlotOption = LAAppGroupSettings.smallWidgetSlot()

    private let slotLabels = ["Top left", "Top right", "Bottom left", "Bottom right"]

    var body: some View {
        Form {
            Section(header: Text("Live Activity")) {
                Toggle("Enable Live Activity", isOn: $laEnabled)
            }

            if laEnabled {
                Section {
                    Button(restartConfirmed ? "Live Activity Restarted" : "Restart Live Activity") {
                        LiveActivityManager.shared.forceRestart()
                        restartConfirmed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            restartConfirmed = false
                        }
                    }
                    .disabled(restartConfirmed)
                }
            }

            Section(header: Text("Grid Slots - Live Activity")) {
                ForEach(0 ..< 4, id: \.self) { index in
                    Picker(slotLabels[index], selection: Binding(
                        get: { slots[index] },
                        set: { selectSlot($0, at: index) }
                    )) {
                        ForEach(LiveActivitySlotOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }
            }

            Section(header: Text("Grid Slot - CarPlay / Watch")) {
                Picker("Right slot", selection: Binding(
                    get: { smallWidgetSlot },
                    set: { newValue in
                        smallWidgetSlot = newValue
                        LAAppGroupSettings.setSmallWidgetSlot(newValue)
                        LiveActivityManager.shared.refreshFromCurrentState(reason: "small widget slot changed")
                    }
                )) {
                    ForEach(LiveActivitySlotOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            }
        }
        .onReceive(Storage.shared.laEnabled.$value) { newValue in
            if newValue != laEnabled { laEnabled = newValue }
        }
        .onChange(of: laEnabled) { newValue in
            Storage.shared.laEnabled.value = newValue
            if newValue {
                LiveActivityManager.shared.forceRestart()
            } else {
                LiveActivityManager.shared.end(dismissalPolicy: .immediate)
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationTitle("Live Activity")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Selects an option for the given slot index, enforcing uniqueness:
    /// if the chosen option is already in another slot, that slot is cleared to `.none`.
    private func selectSlot(_ option: LiveActivitySlotOption, at index: Int) {
        if option != .none {
            for i in 0 ..< slots.count where i != index && slots[i] == option {
                slots[i] = .none
            }
        }
        slots[index] = option
        LAAppGroupSettings.setSlots(slots)
        LiveActivityManager.shared.refreshFromCurrentState(reason: "slot config changed")
    }
}
