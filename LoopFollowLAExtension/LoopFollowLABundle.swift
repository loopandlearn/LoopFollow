// LoopFollow
// LoopFollowLABundle.swift

// LoopFollowLABundle.swift
// Philippe Achkar
// 2026-03-07

import SwiftUI
import WidgetKit

@main
struct LoopFollowLABundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            // CarPlay Dashboard + Watch Smart Stack support (iOS 18+)
            LoopFollowLiveActivityWidgetWithCarPlay()
        } else {
            LoopFollowLiveActivityWidget()
        }
    }
}
