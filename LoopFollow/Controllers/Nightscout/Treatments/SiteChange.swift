// LoopFollow
// SiteChange.swift
// Created by Jonas Björkert on 2023-10-06.

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
