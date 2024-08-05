//
//  InfoDisplaySettingsViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-05.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import SwiftUI

class InfoDisplaySettingsViewModel: ObservableObject {
    @Published var infoSort: [Int]
    @Published var infoVisible: [Bool]

    init() {
        self.infoSort = UserDefaultsRepository.infoSort.value
        self.infoVisible = UserDefaultsRepository.infoVisible.value
    }

    func toggleVisibility(for sortedIndex: Int) {
        infoVisible[sortedIndex].toggle()
        // Update UserDefaults
        UserDefaultsRepository.infoVisible.value = infoVisible
    }

    func move(from source: IndexSet, to destination: Int) {
        infoSort.move(fromOffsets: source, toOffset: destination)
        // Update UserDefaults
        UserDefaultsRepository.infoSort.value = infoSort
    }

    func getName(for index: Int) -> String {
        guard let infoType = InfoType(rawValue: index) else {
            return "Unknown"
        }
        return infoType.name
    }
}
