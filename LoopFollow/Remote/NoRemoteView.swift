//
//  NoRemoteView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct NoRemoteView: View {
    private let remoteController = TrioNightscoutRemoteController()

    var body: some View {
        NavigationView {
            VStack {
                ErrorMessageView(
                    message: "Remote commands are currently only available for Trio and Loop."
                )
            }
        }
    }
}
