// LoopFollow
// LoopFollowLABundle.swift

import SwiftUI
import WidgetKit

@main
struct LoopFollowLABundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        if #available(iOSApplicationExtension 18.0, *) {
            LoopFollowLiveActivityWidgetWithCarPlay()
        }

        if #unavailable(iOSApplicationExtension 18.0) {
            LoopFollowLiveActivityWidget()
        }
    }
}