// LoopFollow
// Glyph.swift
// Created by Jonas Björkert.

import SwiftUI

struct Glyph: View {
    let symbol: String
    let tint: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(uiColor: .systemGray))
                .frame(width: 28, height: 28)

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(tint)
        }
        .frame(width: 36, height: 36)
    }
}
