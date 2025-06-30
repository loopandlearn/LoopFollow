// LoopFollow
// SiteChange.swift
// Created by Jonas Björkert.

import Foundation

extension MainViewController {
    func processCage(entries: [cageData]) {
        if !entries.isEmpty {
            updateCage(data: entries)
        } else if let cage = currentCage {
            updateCage(data: [cage])
        } else {
            webLoadNSCage()
        }
    }
}
