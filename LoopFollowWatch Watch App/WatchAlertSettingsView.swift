// WatchAlertSettingsView.swift
// LoopFollowWatch Watch App
//
// Alert settings tab. Presented inside a NavigationStack as the last tab in ContentView.
// TODO: Add per-type enabled/disabled toggle when surfacing WatchAlertConfig.enabled.

import SwiftUI

struct WatchAlertSettingsView: View {
    @StateObject private var settings = WatchAppSettings.shared

    private let snoozeOptions = stride(from: 30, through: 720, by: 30).map { $0 }

    var body: some View {
        List {
            Section("Snooze Defaults") {
                Toggle("Snooze all by default", isOn: Binding(
                    get: { settings.snoozeAllByDefault },
                    set: { settings.snoozeAllByDefault = $0 }
                ))

                NavigationLink {
                    SnoozeDefaultPickerView(settings: settings, options: snoozeOptions)
                } label: {
                    HStack {
                        Text("Default duration")
                        Spacer()
                        Text(formattedMinutes(settings.defaultSnoozeMinutes))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Alert Cooldowns") {
                ForEach(WatchAlertType.allCases, id: \.self) { type in
                    NavigationLink {
                        CooldownPickerView(type: type, settings: settings)
                    } label: {
                        HStack {
                            Text(type.displayName)
                            Spacer()
                            Text(formattedSeconds(settings.cooldown(for: type)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(appBuild)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Alert Settings")
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }


    private func formattedMinutes(_ mins: Int) -> String {
        mins < 60 ? "\(mins)m" : (mins % 60 == 0 ? "\(mins/60)h" : "\(mins/60)h \(mins%60)m")
    }

    private func formattedSeconds(_ secs: TimeInterval) -> String {
        formattedMinutes(Int(secs) / 60)
    }
}

// MARK: - Snooze default duration picker

private struct SnoozeDefaultPickerView: View {
    @ObservedObject var settings: WatchAppSettings
    let options: [Int]

    var body: some View {
        List(options, id: \.self) { mins in
            Button {
                settings.defaultSnoozeMinutes = mins
            } label: {
                HStack {
                    Text(label(for: mins))
                    Spacer()
                    if settings.defaultSnoozeMinutes == mins {
                        Image(systemName: "checkmark").foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Default Duration")
    }

    private func label(for mins: Int) -> String {
        mins < 60 ? "\(mins) min" : (mins % 60 == 0 ? "\(mins/60) hr" : "\(mins/60)h \(mins%60)m")
    }
}

// MARK: - Per-type cooldown picker

private struct CooldownPickerView: View {
    let type: WatchAlertType
    @ObservedObject var settings: WatchAppSettings

    // Available cooldown values in seconds: 1–5 min (fine), 10–60 min (coarse)
    private let options: [TimeInterval] = [1,2,3,4,5,10,15,20,30,45,60].map { Double($0) * 60 }

    var body: some View {
        List(options, id: \.self) { secs in
            Button {
                settings.setCooldown(secs, for: type)
            } label: {
                HStack {
                    Text(label(for: secs))
                    Spacer()
                    if settings.cooldown(for: type) == secs {
                        Image(systemName: "checkmark").foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("\(type.displayName) Cooldown")
    }

    private func label(for secs: TimeInterval) -> String {
        let mins = Int(secs) / 60
        return mins < 60 ? "\(mins) min" : "\(mins/60) hr"
    }
}
