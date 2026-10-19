// LoopFollow
// RemotePage.swift

import SwiftUI

/// Remote commands, laid out like the phone's Remote tab. Every command is sent
/// by the phone, which applies its own guardrails before contacting Loop or Trio.
struct RemotePage: View {
    let state: WatchState
    let remote: WatchRemoteConfig
    @EnvironmentObject private var session: WatchSession

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if !session.isReachable {
                    Label("iPhone not reachable", systemImage: "iphone.slash")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    NavigationLink {
                        MealEntryView(remote: remote)
                    } label: {
                        RemoteTile(title: "Meal", icon: "fork.knife")
                    }
                    NavigationLink {
                        BolusEntryView(state: state, remote: remote)
                    } label: {
                        RemoteTile(title: "Bolus", icon: "syringe")
                    }
                    if remote.kind == .trio {
                        NavigationLink {
                            PresetListView(kind: .tempTarget, state: state, presets: remote.tempTargetPresets)
                        } label: {
                            RemoteTile(title: "Temp Target", icon: "scope", isActive: state.snapshot?.tempTargetMgdl != nil)
                        }
                    }
                    NavigationLink {
                        PresetListView(kind: .override, state: state, presets: remote.overridePresets)
                    } label: {
                        RemoteTile(title: "Overrides", icon: "slider.horizontal.3", isActive: state.snapshot?.override != nil)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!session.isReachable)
                .opacity(session.isReachable ? 1 : 0.4)
            }
        }
        .navigationTitle(remote.kind == .trio ? "Trio Remote" : "Loop Remote")
    }
}

/// Same look as the phone's CommandButtonView: blue tile, white icon, green glow while active.
struct RemoteTile: View {
    let title: String
    let icon: String
    var isActive = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(title)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 2)
            }
        }
    }
}
