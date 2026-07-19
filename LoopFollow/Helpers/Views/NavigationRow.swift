// LoopFollow
// NavigationRow.swift

import SwiftUI

struct NavigationRow<Value: Hashable>: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var iconTint: Color = .white
    let value: Value

    var body: some View {
        NavigationLink(value: value) {
            HStack {
                Glyph(symbol: icon, tint: iconTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
