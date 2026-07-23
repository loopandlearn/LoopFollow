// LoopFollow
// StorageLoadingView.swift

import SwiftUI

/// Shown at the root until `StorageReadiness.ready` — only while a BFU background
/// launch is foregrounded mid-hydration; a normal launch opens straight to
/// `MainTabView`. Must not read `Storage` (values are poisoned here) — system
/// colors only.
struct StorageLoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
        }
    }
}
