// LoopFollow
// UUID+Identifiable.swift

import Foundation

extension UUID: @retroactive Identifiable {
    public var id: UUID {
        self
    }
}
