// LoopFollow
// InfoDisplaySettingsViewModel.swift
// Created by Jonas Björkert on 2024-08-05.

import Foundation
import SwiftUI

class InfoDisplaySettingsViewModel: ObservableObject {
    @Published var infoSort: [Int]
    @Published var infoVisible: [Bool]

    init() {
        infoSort = Storage.shared.infoSort.value
        infoVisible = Storage.shared.infoVisible.value
    }

    func toggleVisibility(for sortedIndex: Int) {
        infoVisible[sortedIndex].toggle()
        Storage.shared.infoVisible.value = infoVisible
    }

    func move(from source: IndexSet, to destination: Int) {
        infoSort.move(fromOffsets: source, toOffset: destination)
        Storage.shared.infoSort.value = infoSort
    }

    func getName(for index: Int) -> String {
        guard let infoType = InfoType(rawValue: index) else {
            return "Unknown"
        }
        return infoType.name
    }
}
