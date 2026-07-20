// LoopFollow
// GeneralAlarmsStepView.swift

import SwiftUI

/// A short set of the alarm-wide settings that matter most up front: when the
/// day and night periods begin (used by day/night alarm options) and how alarm
/// sound is handled. The full set lives in the Menu.
struct GeneralAlarmsStepView: View {
    @ObservedObject private var cfgStore = Storage.shared.alarmConfiguration

    private var dayBinding: Binding<Date> {
        timeBinding(\.dayStart)
    }

    private var nightBinding: Binding<Date> {
        timeBinding(\.nightStart)
    }

    var body: some View {
        Form {
            Section {
                EmptyView()
            } header: {
                OnboardingStepHeader(
                    systemImage: "slider.horizontal.3",
                    title: "Alarm basics",
                    subtitle: "Set when your day and night begin, and how alarm sound behaves. You can fine-tune everything later in the Menu."
                )
                .textCase(nil)
                .padding(.bottom, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                DatePicker("Day starts", selection: dayBinding, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                DatePicker("Night starts", selection: nightBinding, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
            } header: {
                Text("Day / Night")
            } footer: {
                Text("Alarms can behave differently during the day and at night.")
            }

            Section {
                Toggle("Override system volume", isOn: $cfgStore.value.overrideSystemOutputVolume)

                if cfgStore.value.overrideSystemOutputVolume {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        Slider(value: $cfgStore.value.forcedOutputVolume, in: 0 ... 1)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                    }
                }

                Toggle("Play sound during calls", isOn: $cfgStore.value.audioDuringCalls)
            } header: {
                Text("Sound")
            } footer: {
                Text("Overriding the system volume lets alarms be heard even when your phone is silenced or in a Focus mode.")
            }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<AlarmConfiguration, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = cfgStore.value[keyPath: keyPath].hour
                components.minute = cfgStore.value[keyPath: keyPath].minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let hm = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                cfgStore.value[keyPath: keyPath] = TimeOfDay(hour: hm.hour ?? 0, minute: hm.minute ?? 0)
            }
        )
    }
}
