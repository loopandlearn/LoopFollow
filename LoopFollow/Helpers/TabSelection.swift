// LoopFollow
// TabSelection.swift
// Created by Jonas Björkert.

enum TabSelection: String, CaseIterable, Codable {
    case alarms
    case remote
    case nightscout

    var displayName: String {
        switch self {
        case .alarms: return "Alarms"
        case .remote: return "Remote"
        case .nightscout: return "Nightscout"
        }
    }

    var systemImage: String {
        switch self {
        case .alarms: return "alarm"
        case .remote: return "antenna.radiowaves.left.and.right"
        case .nightscout: return "safari"
        }
    }

    var storyboardIdentifier: String {
        switch self {
        case .alarms: return "AlarmViewController"
        case .remote: return "RemoteViewController"
        case .nightscout: return "NightscoutViewController"
        }
    }
}
