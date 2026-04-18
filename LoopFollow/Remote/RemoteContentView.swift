// LoopFollow
// RemoteContentView.swift

import Combine
import SwiftUI

struct RemoteContentView: View {
    @ObservedObject private var device = Storage.shared.device
    @ObservedObject private var remoteType = Storage.shared.remoteType

    var body: some View {
        Group {
            switch remoteType.value {
            case .nightscout:
                if device.value == "Trio" {
                    TrioNightscoutRemoteView()
                } else {
                    NoRemoteView()
                }

            case .trc:
                if device.value == "Trio" {
                    TrioRemoteControlView(viewModel: TrioRemoteControlViewModel())
                } else {
                    Text("Trio Remote Control is only supported for 'Trio'")
                }

            case .loopAPNS:
                LoopAPNSRemoteView()

            case .none:
                Text("Please select a Remote Type in Settings.")
            }
        }
        .onAppear {
            verifyNightscoutAuth()
        }
    }

    private func verifyNightscoutAuth() {
        guard remoteType.value == .nightscout, !Storage.shared.nsWriteAuth.value else { return }
        NightscoutUtils.verifyURLAndToken { _, _, nsWriteAuth, nsAdminAuth in
            DispatchQueue.main.async {
                Storage.shared.nsWriteAuth.value = nsWriteAuth
                Storage.shared.nsAdminAuth.value = nsAdminAuth
            }
        }
    }
}
