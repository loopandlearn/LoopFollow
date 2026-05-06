// LoopFollow
// WatchRemoteCommandsView.swift
// Root remote commands tab on the Watch.

import SwiftUI

struct WatchRemoteCommandsView: View {
    let snapshot: GlucoseSnapshot?

    var body: some View {
        List {
            NavigationLink {
                WatchMealCommandView()
            } label: {
                Label("Meal", systemImage: "fork.knife")
            }

            NavigationLink {
                WatchOverridePickerView()
            } label: {
                Label("Presets", systemImage: "list.bullet")
            }

            NavigationLink {
                WatchBolusCommandView(snapshot: snapshot)
            } label: {
                Label("Bolus", systemImage: "syringe")
            }
        }
        .navigationTitle("Remote")
    }
}
