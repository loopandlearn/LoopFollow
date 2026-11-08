// LoopFollow
// LoopFollowLABundle.swift

import SwiftUI
import WidgetKit

@main
struct LoopFollowLABundle: WidgetBundle {
    var body: some Widget {
        LoopFollowLiveActivityWidget()
        if #available(iOS 26.0, *) {
            CarPlayWidget()
        }
    }
}
