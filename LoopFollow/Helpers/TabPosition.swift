// LoopFollow
// TabPosition.swift
// Created by Jonas Björkert.

enum TabPosition: String, CaseIterable, Codable {
    case position2
    case position4
    case more
    case disabled

    var displayName: String {
        switch self {
        case .position2: return "Tab 2"
        case .position4: return "Tab 4"
        case .more: return "More Menu"
        case .disabled: return "Hidden"
        }
    }
}
