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
        LoopFollowLiveActivityWidget()
        if #available(iOS 18.0, *) {
            LoopFollowLiveActivityWidgetWithCarPlay()
        }
    }
}
