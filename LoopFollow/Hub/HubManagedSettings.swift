// LoopFollow
// HubManagedSettings.swift

import SwiftUI

/// Data-source settings while LF Hub keeps the patient's data source the same on every
/// phone. A member sees them read only. An admin confirms once that a change reaches every
/// phone; the change then goes to the hub after the app's own check of it. While this
/// phone's settings are not the hub's, an admin can put the hub's back or try again.
struct HubManagedSources<Content: View>: View {
    @ViewBuilder let content: Content

    @ObservedObject private var deviceKey = HubClient.shared.deviceKey
    @ObservedObject private var role = HubClient.shared.role
    @ObservedObject private var hubInfo = HubClient.shared.hubInfo
    @ObservedObject private var patientName = HubClient.shared.patientName
    @ObservedObject private var sync = HubSourceSync.shared
    @ObservedObject private var url = Storage.shared.url
    @ObservedObject private var token = Storage.shared.token
    @ObservedObject private var dexcomUser = Storage.shared.shareUserName
    @ObservedObject private var dexcomPassword = Storage.shared.sharePassword
    @ObservedObject private var dexcomServer = Storage.shared.shareServer
    @State private var unlocked = false
    @State private var confirming = false

    private var patient: String {
        patientName.value.isEmpty ? "the patient" : patientName.value
    }

    var body: some View {
        if sync.isActive {
            Section {
                if HubClient.shared.isAdmin {
                    if unlocked {
                        changeStatus
                    } else if sync.differsFromHub {
                        notShared(sync.state.failure)
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
            .onDisappear { if unlocked { sync.endEditing() } }
        }
        Group { content }
            .disabled(sync.isActive && !(HubClient.shared.isAdmin && unlocked))
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
            notShared(reason)
        }
    }

    /// This phone's data source is not the one LF Hub shares: why, and the way back.
    @ViewBuilder
    private func notShared(_ reason: String?) -> some View {
        Label("Not shared with LF Hub", systemImage: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
        Text((reason.map { $0 + " " } ?? "")
            + "Until it is, this phone's data source is not the one other phones use.")
            .font(.footnote)
            .foregroundColor(.secondary)
        Button("Undo") { Task { await sync.undo() } }
        Button("Try Again") { Task { await sync.retry() } }
    }
}

extension HubSourceSync.State {
    /// Why the last change did not reach the hub, if it did not.
    var failure: String? {
        if case let .failed(reason) = self { return reason }
        return nil
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
