// LoopFollow
// HubManagedSettings.swift

import SwiftUI

/// Data-source settings while LF Hub keeps the patient's data source the same on every
/// phone. A member, and any phone that joined with an invite, sees them read only. An admin confirms once that a change reaches every
/// phone; the change then goes to the hub after the app's own check of it.
struct HubManagedSources<Content: View>: View {
    @ViewBuilder let content: Content

    @ObservedObject private var deviceKey = HubClient.shared.deviceKey
    @ObservedObject private var role = HubClient.shared.role
    @ObservedObject private var hubInfo = HubClient.shared.hubInfo
    @ObservedObject private var patientName = HubClient.shared.patientName
    @ObservedObject private var sync = HubSourceSync.shared
    @State private var unlocked = false
    @State private var confirming = false

    private var patient: String {
        patientName.value.isEmpty ? "the patient" : patientName.value
    }

    var body: some View {
        if sync.isActive {
            Section {
                if HubClient.shared.sendsOwnSources {
                    if unlocked {
                        changeStatus
                    } else {
                        Text("LF Hub shares this data source with every phone following \(patient).")
                            .foregroundColor(.secondary)
                        Button("Change Data Source") { confirming = true }
                    }
                } else {
                    Label("Managed by LF Hub", systemImage: "lock.fill")
                    Text("An admin sets \(patient)'s data source for every phone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .alert("Change the data source?", isPresented: $confirming) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") {
                    sync.beginEditing()
                    unlocked = true
                }
            } message: {
                Text("This changes the data source for everyone following \(patient).")
            }
        }
        Group { content }
            .disabled(sync.isActive && !(HubClient.shared.sendsOwnSources && unlocked))
    }

    @ViewBuilder
    private var changeStatus: some View {
        switch sync.state {
        case .idle:
            Text("Changes go to LF Hub once LoopFollow has checked them.")
                .font(.footnote)
                .foregroundColor(.secondary)
        case .checking:
            HStack {
                ProgressView()
                Text("Checking the data source…").foregroundColor(.secondary)
            }
        case .sent:
            Label("Sent to LF Hub", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case let .failed(reason):
            Text(reason).font(.footnote).foregroundColor(.red)
            Button("Try Again") { Task { await sync.retry() } }
        }
    }
}

/// The APN settings while LF Hub pushes to this phone with the APN key an admin added.
struct HubManagedApnKey<Content: View>: View {
    @ViewBuilder let content: Content

    @ObservedObject private var deviceKey = HubClient.shared.deviceKey
    @ObservedObject private var apnsKeyShared = HubClient.shared.apnsKeyShared

    private var shared: Bool {
        HubClient.shared.isConnected && apnsKeyShared.value && !HubClient.hasOwnApnKey
    }

    var body: some View {
        if shared {
            Section {
                Label("Managed by LF Hub", systemImage: "lock.fill")
                Text("LF Hub notifies this phone with the APN key an admin added.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        Group { content }
            .disabled(shared)
    }
}
