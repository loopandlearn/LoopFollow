//
//  LoadingButtonView.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-09-17.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct LoadingButtonView: View {
    var buttonText: String
    var progressText: String
    var isLoading: Bool
    var action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Section {
            VStack {
                if isLoading {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 10)
                        Text(progressText)
                    }
                    .padding()
                } else {
                    Button(action: {
                        action()
                    }) {
                        Text(buttonText)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowInsets(EdgeInsets())
        }
    }
}
