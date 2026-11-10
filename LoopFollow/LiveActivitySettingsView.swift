// LoopFollow
// LiveActivitySettingsView.swift

#if !targetEnvironment(macCatalyst)

    import SwiftUI

    struct LiveActivitySettingsView: View {
        @State private var laEnabled: Bool = Storage.shared.laEnabled.value
        @State private var restartConfirmed = false
        @State private var slots: [LiveActivitySlotOption] = LAAppGroupSettings.slots()
        @State private var smallWidgetSlot: LiveActivitySlotOption = LAAppGroupSettings.smallWidgetSlot()
        @State private var showSmallWidgetStatusLine: Bool = LAAppGroupSettings.showSmallWidgetStatusLine()
        @State private var smallWidgetTightLayout: Bool = LAAppGroupSettings.smallWidgetTightLayout()
        @State private var keyId: String = Storage.shared.lfKeyId.value
        @State private var apnsKey: String = Storage.shared.lfApnsKey.value

        private let slotLabels = ["Top left", "Top right", "Bottom left", "Bottom right"]

        private var apnsConfigured: Bool {
            APNsCredentialValidator.isFullyConfigured(keyId: keyId, apnsKey: apnsKey)
        }

        var body: some View {
            Form {
                Section(
                    header: Text("Live Activity"),
                    footer: Text("Live Activity updates require APNs credentials. Configure them in Settings → APN.")
                ) {
                    Toggle("Enable Live Activity", isOn: $laEnabled)
                }

                if laEnabled {
                    if !apnsConfigured {
                        Section {
                            Label {
                                Text("APNs credentials are missing or invalid — Live Activity updates will not work. Open Settings → APN to fix.")
                                    .font(.callout)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }

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
                            ForEach(LiveActivitySlotOption.gridCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    }
                }

                Section(header: Text("Grid Slot - CarPlay / Watch")) {
                    let rightSlotOptions = LiveActivitySlotOption.smallWidgetCases(showStatusLine: showSmallWidgetStatusLine)
                    Picker("Right slot", selection: Binding(
                        get: { rightSlotOptions.contains(smallWidgetSlot) ? smallWidgetSlot : .none },
                        set: { newValue in
                            smallWidgetSlot = newValue
                            LAAppGroupSettings.setSmallWidgetSlot(newValue)
                            LiveActivityManager.shared.refreshFromCurrentState(reason: "small widget slot changed")
                        }
                    )) {
                        ForEach(rightSlotOptions, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { showSmallWidgetStatusLine },
                        set: { newValue in
                            showSmallWidgetStatusLine = newValue
                            LAAppGroupSettings.setShowSmallWidgetStatusLine(newValue)
                            LiveActivityManager.shared.refreshFromCurrentState(reason: "small widget status line changed")
                        }
                    )) {
                        InfoLabel(title: "Status Line", info: Self.statusLineInfo)
                    }

                    Toggle(isOn: Binding(
                        get: { smallWidgetTightLayout },
                        set: { newValue in
                            smallWidgetTightLayout = newValue
                            LAAppGroupSettings.setSmallWidgetTightLayout(newValue)
                            LiveActivityManager.shared.refreshFromCurrentState(reason: "small widget tight layout changed")
                        }
                    )) {
                        InfoLabel(title: "Tight CarPlay Layout", info: Self.tightLayoutInfo)
                    }
                }
            }
            .onReceive(Storage.shared.laEnabled.$value) { newValue in
                if newValue != laEnabled { laEnabled = newValue }
            }
            .onReceive(Storage.shared.lfKeyId.$value) { newValue in
                if newValue != keyId { keyId = newValue }
            }
            .onReceive(Storage.shared.lfApnsKey.$value) { newValue in
                if newValue != apnsKey { apnsKey = newValue }
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

        private static let statusLineInfo = "Shows a line under the reading with the update time, IOB and COB, or Not Looping when Loop stops reporting, then any active override with its insulin needs, range and time left. While it is on, IOB, COB and Override are not offered for the right slot. Changes appear with the next Live Activity update."

        private static let tightLayoutInfo = "Replaces the right slot with projected BG, IOB, COB and basal stacked on the right, and reduces the status line to the time. It only applies to wide CarPlay screens; the Watch and narrow CarPlay screens keep the regular layout. Changes appear with the next Live Activity update."

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

    /// A setting's title followed by an info button that explains it in a popover.
    private struct InfoLabel: View {
        let title: String
        let info: String
        @State private var showInfo = false

        var body: some View {
            HStack(spacing: 6) {
                Text(title)
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                }
                // Borderless keeps the tap on the icon instead of the whole row.
                .buttonStyle(.borderless)
                .accessibilityLabel("About \(title)")
                .popover(isPresented: $showInfo) {
                    Text(info)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 280, alignment: .leading)
                        .padding()
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
#endif
