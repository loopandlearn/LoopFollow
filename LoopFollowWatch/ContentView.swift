// LoopFollow
// ContentView.swift

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: WatchSession

    var body: some View {
        NavigationStack {
            if let state = session.state {
                TabView {
                    GlucosePage(state: state)
                    if let remote = state.remote {
                        RemotePage(state: state, remote: remote)
                    }
                    // Last, so its length never stands between the other pages.
                    InfoPage(state: state)
                }
                .tabViewStyle(.verticalPage)
            } else {
                WaitingForPhoneView()
            }
        }
    }
}

private struct WaitingForPhoneView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Waiting for LoopFollow on iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Open LoopFollow on the paired iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
