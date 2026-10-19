// LoopFollow
// InfoPage.swift

import SwiftUI

/// The phone's info table: the same rows, order and threshold coloring.
struct InfoPage: View {
    let state: WatchState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if state.infoRows.isEmpty {
                    Text("No info rows are shown on the iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(state.infoRows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.name)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.value)
                            .foregroundStyle(Self.color(row.level))
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.vertical, 3)
                    Divider()
                }
            }
            // Keeps the values clear of the page indicator.
            .padding(.trailing, 10)
        }
        .navigationTitle("Info")
    }

    /// Same colors as the phone's InfoColoring.
    static func color(_ level: InfoColorLevel?) -> Color {
        switch level {
        case .urgent: .red
        case .warning: .yellow
        case .normal: .green
        case nil: .primary
        }
    }
}
