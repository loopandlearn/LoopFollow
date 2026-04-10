// LoopFollow
// LALivenessStore.swift

import Foundation

enum LALivenessStore {
    private static let defaults = UserDefaults(suiteName: AppGroupID.baseBundleID)

    private enum Key {
        static let lastExtensionSeenAt = "la.liveness.lastExtensionSeenAt"
        static let lastExtensionSeq = "la.liveness.lastExtensionSeq"
        static let lastExtensionProducedAt = "la.liveness.lastExtensionProducedAt"
    }

    static func markExtensionRender(seq: Int, producedAt: Date) {
        defaults?.set(Date().timeIntervalSince1970, forKey: Key.lastExtensionSeenAt)
        defaults?.set(seq, forKey: Key.lastExtensionSeq)
        defaults?.set(producedAt.timeIntervalSince1970, forKey: Key.lastExtensionProducedAt)
    }

    static var lastExtensionSeenAt: TimeInterval {
        defaults?.double(forKey: Key.lastExtensionSeenAt) ?? 0
    }

    static var lastExtensionSeq: Int {
        defaults?.integer(forKey: Key.lastExtensionSeq) ?? 0
    }

    static var lastExtensionProducedAt: TimeInterval {
        defaults?.double(forKey: Key.lastExtensionProducedAt) ?? 0
    }

    static func clear() {
        defaults?.removeObject(forKey: Key.lastExtensionSeenAt)
        defaults?.removeObject(forKey: Key.lastExtensionSeq)
        defaults?.removeObject(forKey: Key.lastExtensionProducedAt)
    }
}
