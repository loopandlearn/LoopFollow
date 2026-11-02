// LoopFollow
// LabeledValueRow.swift

import SwiftUI

/// A label on the left and its value, in secondary color, on the right.
struct LabeledValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}
