//
//  InsulinCartridgeChange.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-05.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

extension MainViewController {
    func processIage(entries: [iageData]) {
        if !entries.isEmpty {
            updateIage(data: entries)
        } else if let iage = currentIage {
            updateIage(data: [iage])
        } else if UserDefaultsRepository.infoVisible.value[InfoType.iage.rawValue] {
            webLoadNSIage()
        }
    }
}
