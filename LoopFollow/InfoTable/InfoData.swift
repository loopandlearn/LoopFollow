// LoopFollow
// InfoData.swift

import Foundation

class InfoData: Identifiable {
    let id: Int
    let name: String
    var value: String
    /// Raw numeric value behind `value`, when the row carries a single number.
    /// Used for threshold-based coloring; `nil` for text or combined values.
    var numericValue: Double?

    init(id: Int, name: String, value: String = "", numericValue: Double? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.numericValue = numericValue
    }
}
