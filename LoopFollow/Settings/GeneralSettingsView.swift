// LoopFollow
// GeneralSettingsView.swift

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var units = Storage.shared.units
    @ObservedObject var colorBGText = Storage.shared.colorBGText
    @ObservedObject var appBadge = Storage.shared.appBadge
    @ObservedObject var appearanceMode = Storage.shared.appearanceMode
    @ObservedObject var showStats = Storage.shared.showStats
    @ObservedObject var useIFCC = Storage.shared.useIFCC
    @ObservedObject var showSmallGraph = Storage.shared.showSmallGraph
    @ObservedObject var screenlockSwitchState = Storage.shared.screenlockSwitchState
    @ObservedObject var showDisplayName = Storage.shared.showDisplayName
    @ObservedObject var snoozerEmoji = Storage.shared.snoozerEmoji
    @ObservedObject var forcePortraitMode = Storage.shared.forcePortraitMode
    @ObservedObject var persistentNotification = Storage.shared.persistentNotification

    // Speak-BG settings
    @ObservedObject var speakBG = Storage.shared.speakBG
    @ObservedObject var speakBGAlways = Storage.shared.speakBGAlways
    @ObservedObject var speakLanguage = Storage.shared.speakLanguage
    @ObservedObject var speakLowBG = Storage.shared.speakLowBG
    @ObservedObject var speakProactiveLowBG = Storage.shared.speakProactiveLowBG
    @ObservedObject var speakLowBGLimit = Storage.shared.speakLowBGLimit
    @ObservedObject var speakFastDropDelta = Storage.shared.speakFastDropDelta
    @ObservedObject var speakHighBG = Storage.shared.speakHighBG
    @ObservedObject var speakHighBGLimit = Storage.shared.speakHighBGLimit

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $units.value) {
                    Text("mg/dL").tag("mg/dL")
                    Text("mmol/L").tag("mmol/L")
                }
                .pickerStyle(.menu)
            } header: {
                Label("Units", systemImage: "ruler")
            }

            Section {
                Toggle("Display App Badge", isOn: $appBadge.value)
                Toggle("Persistent Notification", isOn: $persistentNotification.value)
            } header: {
                Label("App Settings", systemImage: "gear")
            } footer: {
                Text("App Badge shows your current BG on the app icon. Persistent Notification keeps a notification visible for quick access.")
            }

            Section {
                Picker("Appearance", selection: $appearanceMode.value) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle("Display Stats", isOn: $showStats.value)
                Toggle("Use IFCC A1C", isOn: $useIFCC.value)
                Toggle("Display Small Graph", isOn: $showSmallGraph.value)
                Toggle("Color BG Text", isOn: $colorBGText.value)
                Toggle("Keep Screen Active", isOn: $screenlockSwitchState.value)
                Toggle("Show Display Name", isOn: $showDisplayName.value)
                Toggle("Snoozer emoji", isOn: $snoozerEmoji.value)
                Toggle("Force portrait mode", isOn: $forcePortraitMode.value)
                    .onChange(of: forcePortraitMode.value) { _ in
                        if #available(iOS 16.0, *) {
                            let window = UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .flatMap { $0.windows }
                                .first

                            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                        }
                    }
            } header: {
                Label("Display", systemImage: "display")
            }

            Section {
                Toggle("Speak BG", isOn: $speakBG.value.animation())

                if speakBG.value {
                    Picker("Language", selection: $speakLanguage.value) {
                        Text("English").tag("en")
                        Text("Italian").tag("it")
                        Text("Slovak").tag("sk")
                        Text("Swedish").tag("sv")
                    }

                    Toggle("Always", isOn: $speakBGAlways.value.animation())

                    if !speakBGAlways.value {
                        Toggle("Low", isOn: $speakLowBG.value.animation())
                            .onChange(of: speakLowBG.value) { newValue in
                                if newValue {
                                    speakProactiveLowBG.value = false
                                }
                            }

                        Toggle("Proactive Low", isOn: $speakProactiveLowBG.value.animation())
                            .onChange(of: speakProactiveLowBG.value) { newValue in
                                if newValue {
                                    speakLowBG.value = false
                                }
                            }

                        if speakLowBG.value || speakProactiveLowBG.value {
                            BGPicker(
                                title: "Low BG Limit",
                                range: 40 ... 108,
                                value: $speakLowBGLimit.value
                            )
                        }

                        if speakProactiveLowBG.value {
                            BGPicker(
                                title: "Fast Drop Delta",
                                range: 3 ... 20,
                                value: $speakFastDropDelta.value
                            )
                        }

                        Toggle("High", isOn: $speakHighBG.value.animation())

                        if speakHighBG.value {
                            BGPicker(
                                title: "High BG Limit",
                                range: 140 ... 300,
                                value: $speakHighBGLimit.value
                            )
                        }
                    }
                }
            } header: {
                Label("Speak BG", systemImage: "speaker.wave.2")
            } footer: {
                Text("Speak BG reads your blood glucose aloud. Use 'Always' to hear every reading, or set specific thresholds for low and high alerts.")
            }
        }
        .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
        .navigationBarTitle("General Settings", displayMode: .inline)
        .settingsStyle(title: "General Settings")
    }
}
