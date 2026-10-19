// LoopFollow
// PresetListView.swift

import SwiftUI

/// Override or temp target presets synced from the phone, with a cancel row
/// while one is active.
struct PresetListView: View {
    enum Kind {
        case override
        case tempTarget
    }

    let kind: Kind
    let state: WatchState
    let presets: [WatchPreset]

    @Environment(\.dismiss) private var dismiss

    private var activeText: String? {
        guard let snapshot = state.snapshot else { return nil }
        switch kind {
        case .override:
            return snapshot.override
        case .tempTarget:
            return snapshot.tempTargetMgdl.map { WatchFormat.glucose($0, unit: snapshot.unit) }
        }
    }

    private var title: String { kind == .override ? "Overrides" : "Temp Target" }

    var body: some View {
        List {
            if let activeText {
                Section("Active") {
                    NavigationLink {
                        CommandConfirmView(
                            title: kind == .override ? "Cancel Override" : "Cancel Temp Target",
                            lines: ["Cancel \(activeText)?"],
                            action: kind == .override ? .cancelOverride : .cancelTempTarget,
                            deliversInsulin: false,
                            onSuccess: { dismiss() }
                        )
                    } label: {
                        Label(activeText, systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Presets") {
                if presets.isEmpty {
                    Text(kind == .override ? "No override presets found." : "No temp target presets. Add them in LoopFollow on the iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(presets) { preset in
                    NavigationLink {
                        CommandConfirmView(
                            title: title,
                            lines: [preset.name, preset.detail],
                            action: kind == .override ? .startOverride(presetID: preset.id) : .startTempTarget(presetID: preset.id),
                            deliversInsulin: false,
                            onSuccess: { dismiss() }
                        )
                    } label: {
                        VStack(alignment: .leading) {
                            Text(preset.name)
                            Text(preset.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}
