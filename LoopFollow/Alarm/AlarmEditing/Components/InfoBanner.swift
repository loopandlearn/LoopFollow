// LoopFollow
// InfoBanner.swift

import SwiftUI

struct InfoBanner: View {
    /// Main explanatory text
    let text: String

    /// Optional alarm type whose icon you’d like to show.
    /// If `nil`, we fall back to the standard “info” symbol.
    var alarmType: AlarmType? = nil

    /// Colour for the leading symbol
    var iconColour: Color = .accentColor

    /// Background + border tints
    var tint: Color = Color.blue.opacity(0.20)
    var border: Color = Color.blue.opacity(0.40)

    /// ────────── View ──────────
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alarmType?.icon ?? "info.circle.fill")
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
