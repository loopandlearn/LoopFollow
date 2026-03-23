// LoopFollow
// LoopFollowLABundle.swift

import SwiftUI
import WidgetKit

@main
struct LoopFollowLABundle: WidgetBundle {
    var body: some Widget {
        // Only one ActivityConfiguration for GlucoseLiveActivityAttributes is registered at a time.
        // On iOS 18+, use the supplemental widget which handles Lock Screen, CarPlay, and Watch Smart Stack.
        // On older iOS, use the primary widget (Lock Screen + Dynamic Island only).
        if #available(iOS 18.0, *) {
            LoopFollowLiveActivityWidgetWithCarPlay()
        } else {
            LoopFollowLiveActivityWidget()
        }
    }
}
