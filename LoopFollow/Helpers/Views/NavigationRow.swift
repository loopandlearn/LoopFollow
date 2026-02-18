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
            .preferredColorScheme(Storage.shared.appearanceMode.value.colorScheme)
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

// MARK: - Binding Helpers

extension Binding {
    /// Creates a binding that accesses a property on the wrapped value using a keypath.
    /// Useful for creating bindings to nested properties in storage objects.
    ///
    /// Example:
    /// ```
    /// // Instead of:
    /// Toggle("Override", isOn: Binding(
    ///     get: { cfgStore.value.overrideVolume },
    ///     set: { cfgStore.value.overrideVolume = $0 }
    /// ))
    ///
    /// // Use:
    /// Toggle("Override", isOn: $cfgStore.value.binding(\.overrideVolume))
    /// ```
    func binding<T>(_ keyPath: WritableKeyPath<Value, T>) -> Binding<T> {
        Binding<T>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}
