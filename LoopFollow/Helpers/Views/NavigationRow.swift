// LoopFollow
// NavigationRow.swift

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

// MARK: - Settings View Modifier

struct SettingsStyleModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(Storage.shared.forceDarkMode.value ? .dark : nil)
    }
}

extension View {
    /// Applies standard styling for settings views:
    /// - Sets the navigation title with inline display mode
    /// - Applies dark mode preference if enabled in settings
    func settingsStyle(title: String) -> some View {
        modifier(SettingsStyleModifier(title: title))
    }
}
