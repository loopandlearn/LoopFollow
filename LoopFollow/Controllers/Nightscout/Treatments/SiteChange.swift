//
//  SiteChange.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-10-06.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

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
