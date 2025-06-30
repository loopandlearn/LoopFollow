// LoopFollow
// NavigationRow.swift
// Created by Jonas Björkert.

import SwiftUI

struct NavigationRow: View {
    let title: String
    let icon: String
    var iconTint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Glyph(symbol: icon, tint: iconTint)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
