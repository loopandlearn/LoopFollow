// LoopFollow
// LoopFollowLABundle.swift

import SwiftUI
import WidgetKit

@main
struct LoopFollowLABundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        LegacyLiveActivityBundle()
        ModernLiveActivityBundle()
    }
}

@available(iOSApplicationExtension, introduced: 16.1, obsoleted: 18.0)
struct LegacyLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        LoopFollowLiveActivityWidget()
    }
}

@available(iOSApplicationExtension 18.0, *)
struct ModernLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        LoopFollowLiveActivityWidgetWithCarPlay()
    }
}