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
        case .position1: return "Tab 1"
        case .position2: return "Tab 2"
        case .position3: return "Tab 3"
        case .position4: return "Tab 4"
        case .menu, .more, .disabled: return "Menu"
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
        case .home: return "Home"
        case .alarms: return "Alarms"
        case .remote: return "Remote"
        case .nightscout: return "Nightscout"
        case .snoozer: return "Snoozer"
        case .treatments: return "Treatments"
        case .stats: return "Statistics"
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

    /// Items that can be moved between tab bar and menu (all except settings which doesn't exist as a tab)
    static var movableItems: [TabItem] {
        [.home, .alarms, .remote, .nightscout, .snoozer, .treatments, .stats]
    }
}
