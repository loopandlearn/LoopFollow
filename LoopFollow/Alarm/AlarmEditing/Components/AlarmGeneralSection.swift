// LoopFollow
// AlarmGeneralSection.swift

import SwiftUI

struct AlarmGeneralSection: View {
    @Binding var alarm: Alarm

    var body: some View {
        Section(
            header: Text("General"),
            footer: Text("Give each alarm a unique name—especially if you’ve added more than one of the same kind—so you can tell them apart at a glance.")
        ) {
            HStack {
                Text("Name")
                TextField("Alarm Name", text: $alarm.name)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .foregroundColor(.secondary)
            }
            Toggle("Enabled", isOn: $alarm.isEnabled)
        }
    }
}
