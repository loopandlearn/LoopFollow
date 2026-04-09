// LoopFollow
// LALivenessMarker.swift

import SwiftUI

struct LALivenessMarker: View {
    let seq: Int
    let producedAt: Date

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: markerID) {
                LALivenessStore.markExtensionRender(seq: seq, producedAt: producedAt)
            }
    }

    private var markerID: String {
        "\(seq)-\(producedAt.timeIntervalSince1970)"
    }
}
