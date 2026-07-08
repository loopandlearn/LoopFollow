// LoopFollow
// AppBannerView.swift

import SwiftUI

/// Dismissable banner shown at the top of the app, above the tab content.
struct AppBannerView: View {
    let message: BannerMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)

            Text(message.text)
                .font(.callout)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                BannerManager.shared.dismissCurrent()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch message.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch message.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var tint: Color {
        switch message.severity {
        case .info: return Color.blue.opacity(0.20)
        case .warning: return Color.orange.opacity(0.20)
        case .error: return Color.red.opacity(0.20)
        }
    }

    private var border: Color {
        switch message.severity {
        case .info: return Color.blue.opacity(0.40)
        case .warning: return Color.orange.opacity(0.40)
        case .error: return Color.red.opacity(0.40)
        }
    }
}
