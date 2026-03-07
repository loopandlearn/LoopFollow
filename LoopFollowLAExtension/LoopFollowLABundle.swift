//
//  LoopFollowLABundle.swift
//  LoopFollow
//
//  Created by Philippe Achkar on 2026-03-07.
//  Copyright © 2026 Jon Fawcett. All rights reserved.
//


// LoopFollowLABundle.swift
// Philippe Achkar
// 2026-03-07

import WidgetKit
import SwiftUI

@main
struct LoopFollowLABundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            LoopFollowLiveActivityWidget()
        }
    }
}