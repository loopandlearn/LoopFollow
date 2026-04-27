// LoopFollow
// InfoData.swift

import Foundation

class InfoData: Identifiable {
    let id: Int
    let name: String
    var value: String

    init(id: Int, name: String, value: String = "") {
        self.id = id
        self.name = name
        self.value = value
    }
}
