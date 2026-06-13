// LoopFollow
// NavigationRow.swift

import SwiftUI

struct NavigationRow<Value: Hashable>: View {
    let title: String
    let icon: String
    var iconTint: Color = .white
    let value: Value

    var body: some View {
        NavigationLink(value: value) {
            HStack {
                Glyph(symbol: icon, tint: iconTint)
                Text(title)
            }
        }
    }
}
