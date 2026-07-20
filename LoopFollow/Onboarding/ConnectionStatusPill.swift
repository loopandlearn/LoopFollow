// LoopFollow
// ConnectionStatusPill.swift

import SwiftUI

/// A pinned, color-coded status banner shown at the top of the onboarding
/// connect screens (Nightscout and Dexcom). It morphs as the connection state
/// changes, giving both screens the same live, above-the-fold status treatment.
///
/// The pill itself is state-agnostic: each connect screen maps its own view
/// model's status into a `color`, an optional `systemImage`, and whether to show
/// a spinner, so the two different status enums can share one look.
struct ConnectionStatusPill: View {
    let color: Color
    let message: String
    var isLoading: Bool = false
    var systemImage: String?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isLoading {
                    ProgressView().scaleEffect(0.85)
                } else if let systemImage {
                    Image(systemName: systemImage).foregroundColor(color)
                }
            }
            .frame(width: 20)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
