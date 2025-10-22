// LoopFollow
// InfoDisplaySettingsViewModel.swift

import Foundation
import SwiftUI

class InfoDisplaySettingsViewModel: ObservableObject {
    @Published var infoSort: [Int]
    @Published var infoVisible: [Bool]

    init() {
        var sortArray = Storage.shared.infoSort.value
        var visibleArray = Storage.shared.infoVisible.value

        let currentValidIndices = InfoType.allCases.map { $0.rawValue }

        for index in currentValidIndices where !sortArray.contains(index) {
            sortArray.append(index)
        }

        sortArray = sortArray.filter { currentValidIndices.contains($0) }

        if visibleArray.count < currentValidIndices.count {
            for i in visibleArray.count ..< currentValidIndices.count {
                visibleArray.append(InfoType(rawValue: i)?.defaultVisible ?? false)
            }
        } else if visibleArray.count > currentValidIndices.count {
            visibleArray = Array(visibleArray.prefix(currentValidIndices.count))
        }

        Storage.shared.infoSort.value = sortArray
        Storage.shared.infoVisible.value = visibleArray

        infoSort = sortArray
        infoVisible = visibleArray
    }

    func toggleVisibility(for sortedIndex: Int) {
        guard sortedIndex < infoVisible.count else { return }
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
