// LoopFollow
// HubIndicator.swift

import SwiftUI

/// A server icon before the source name on Home while LF Hub mode is on: blue while the
/// hub answers and reaches this phone, red while it does not (`HubWatchdog.looksHealthy`).
struct HubIndicator: View {
    @ObservedObject private var backgroundRefreshType = Storage.shared.backgroundRefreshType
    @ObservedObject private var hubURL = Storage.shared.hubURL
    @ObservedObject private var deviceKey = HubClient.shared.deviceKey
    @ObservedObject private var looksHealthy = HubWatchdog.looksHealthy

    var body: some View {
        if HubClient.shared.isHubMode {
            Image(systemName: "server.rack")
                .foregroundColor(looksHealthy.value ? .blue : .red)
                .accessibilityLabel(looksHealthy.value ? "LF Hub mode, hub connected" : "LF Hub mode, no contact with the hub")
        }
    }
}
