// LoopFollow
// ActionRow.swift
// Created by Jonas Björkert on 2025-05-27.

import SwiftUI

@ViewBuilder
func ActionRow(
    title: String,
    icon: String,
    tint: Color = .white,
    action: @escaping () -> Void
) -> some View {
    Button { action() } label: {
        HStack {
            Glyph(symbol: icon, tint: tint)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}
