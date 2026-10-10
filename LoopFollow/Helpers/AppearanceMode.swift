// LoopFollow
// AppearanceMode.swift

import SwiftUI

enum AppearanceMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return String(localized: "System", comment: "Appearance mode")
        case .light: return String(localized: "Light", comment: "Appearance mode")
        case .dark: return String(localized: "Dark", comment: "Appearance mode")
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
