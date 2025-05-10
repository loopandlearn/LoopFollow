//
//  InfoBanner.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-05-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//


import SwiftUI

/// Apple-style information banner you can drop into any `Form` / `List` row.
///
/// Usage:
/// ```swift
/// Form {
///     InfoBanner("Triggers when no CGM reading is received for the time you set below.")
///     
///     AlarmGeneralSection(alarm: $alarm)
///     …
/// }
/// ```
struct InfoBanner: View {
    /// The main explanatory text (can be a `String` or a localized key).
    let text: String

    /// Optional SFSymbol (defaults to “info.circle.fill” so you can omit it).
    var systemImage: String = "info.circle.fill"
    
    /// Icon colour (defaults to `.accentColor` so it adapts to light/dark).
    var iconColour: Color = .accentColor
    
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
        .listRowInsets(EdgeInsets())
        .padding(.bottom, 4)
    }
}
