// LoopFollow
// InfoDisplaySettingsViewModel.swift

import Foundation
import SwiftUI

class InfoDisplaySettingsViewModel: ObservableObject {
    @Published var items: [InfoDisplayItem]

    init() {
        items = Storage.shared.infoDisplayItems.value
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// A binding to a single item, looked up by id so it survives reordering.
    /// Writes persist to Storage immediately.
    func binding(for id: Int) -> Binding<InfoDisplayItem> {
        Binding(
            get: { self.items.first(where: { $0.id == id }) ?? self.items[0] },
            set: { newValue in
                guard let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[index] = newValue
                self.persist()
            }
        )
    }

    private func persist() {
        Storage.shared.infoDisplayItems.value = items
    }
}
