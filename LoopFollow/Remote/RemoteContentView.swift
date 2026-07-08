// LoopFollow
// RemoteContentView.swift

import SwiftUI

struct RemoteContentView: View {
    @ObservedObject private var device = Storage.shared.device
    @ObservedObject private var remoteType = Storage.shared.remoteType

    var body: some View {
        Group {
            switch remoteType.value {
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
    }
}
