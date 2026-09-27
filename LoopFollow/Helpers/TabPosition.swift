// LoopFollow
// TabPosition.swift

enum TabPosition: String, CaseIterable, Codable, Comparable {
    case position1
    case position2
    case position3
    case position4
    case menu
    case more
    case disabled

    var displayName: String {
        switch self {
        case .position1: return String(localized: "Tab 1", comment: "Tab position")
        case .position2: return String(localized: "Tab 2", comment: "Tab position")
        case .position3: return String(localized: "Tab 3", comment: "Tab position")
        case .position4: return String(localized: "Tab 4", comment: "Tab position")
        case .menu, .more, .disabled: return String(localized: "Menu", comment: "Tab position")
        }
    }

    /// The index in the tab bar (0-based)
    var tabIndex: Int? {
        switch self {
        case .position1: return 0
        case .position2: return 1
        case .position3: return 2
        case .position4: return 3
        case .menu, .more, .disabled: return 4
        }
    }

    /// Positions that users can customize (1-4)
    static var customizablePositions: [TabPosition] {
        [.position1, .position2, .position3, .position4]
    }

    /// Normalize legacy values to current values
    var normalized: TabPosition {
        switch self {
        case .more, .disabled: return .menu
        default: return self
        }
    }

    // Comparable conformance for sorting
    static func < (lhs: TabPosition, rhs: TabPosition) -> Bool {
        let order: [TabPosition] = [.position1, .position2, .position3, .position4, .menu, .more, .disabled]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

/// Represents a tab item that can be placed in any position
enum TabItem: String, CaseIterable, Codable, Identifiable {
    case home
    case alarms
    case remote
    case nightscout
    case snoozer
    case treatments
    case stats

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: return String(localized: "Home", comment: "Tab / feature name")
        case .alarms: return String(localized: "Alarms", comment: "Tab / feature name")
        case .remote: return String(localized: "Remote", comment: "Tab / feature name")
        case .nightscout: return String(localized: "Nightscout", comment: "Tab / feature name")
        case .snoozer: return String(localized: "Snoozer", comment: "Tab / feature name")
        case .treatments: return String(localized: "Treatments", comment: "Tab / feature name")
        case .stats: return String(localized: "Statistics", comment: "Tab / feature name")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .alarms: return "alarm"
        case .remote: return "antenna.radiowaves.left.and.right"
        case .nightscout: return "safari"
        case .snoozer: return "zzz"
        case .treatments: return "cross.case"
        case .stats: return "chart.bar.xaxis"
        }
    }

    /// Canonical feature order used by menus and customization screens.
    static var featureOrder: [TabItem] {
        [.home, .alarms, .nightscout, .remote, .snoozer, .stats, .treatments]
    }

    /// Items that can be moved between tab bar and menu (all except settings which doesn't exist as a tab)
    static var movableItems: [TabItem] {
        featureOrder
    }
}
