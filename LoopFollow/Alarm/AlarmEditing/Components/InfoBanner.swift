//
//  InfoBanner.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import SwiftUI

struct InfoBanner: View {
    let text: String

    var systemImage: String = "info.circle.fill"

    var iconColour: Color  = .accentColor

    var tint: Color        = Color.blue.opacity(0.20)

    var border: Color      = Color.blue.opacity(0.40)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(iconColour)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .listRowInsets(EdgeInsets())
    }
}
