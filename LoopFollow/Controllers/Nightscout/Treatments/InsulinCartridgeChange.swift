// LoopFollow
// InsulinCartridgeChange.swift

import Foundation

extension MainViewController {
    func processIage(entries: [iageData]) {
        if !entries.isEmpty {
            updateIage(data: entries)
        } else if let iage = currentIage {
            updateIage(data: [iage])
        } else if Storage.shared.infoDisplayItems.value.isVisible(.iage) {
            webLoadNSIage()
        }
    }
}
