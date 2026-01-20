// LoopFollow
// AppearanceMode.swift

import SwiftUI

extension Notification.Name {
    static let appearanceDidChange = Notification.Name("appearanceDidChange")
}

enum AppearanceMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Returns the ColorScheme for SwiftUI's preferredColorScheme modifier
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Returns the UIUserInterfaceStyle for UIKit views
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
