//
//  LoopNightscoutRemoteView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-14.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct LoopNightscoutRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var nsAdmin = ObservableUserDefaults.shared.nsWriteAuth

    var body: some View {
        NavigationView {
            if !nsAdmin.value {
                ErrorMessageView(
                    message: "Please update your token to include the 'admin' role in order to do remote commands."
                )} else {
                    VStack {
                        let columns = [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ]

                        LazyVGrid(columns: columns, spacing: 16) {
                            CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: LoopOverrideView())
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                    .navigationBarTitle("Loop Remote Control", displayMode: .inline)
                }
        }
    }
}
