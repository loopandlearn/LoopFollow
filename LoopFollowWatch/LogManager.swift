// LoopFollow
// LogManager.swift

import Foundation
import os

/// The watch's logger. Same call shape as the phone's LogManager so the code in
/// RemoteShared compiles for both; lines go to the unified system log.
final class LogManager {
    static let shared = LogManager()

    enum Category: String {
        case apns = "APNS"
        case nightscout = "Nightscout"
        case dexcom = "Dexcom"
        case general = "General"
        case remote = "Remote"
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LoopFollowWatch", category: "watch")

    private init() {}

    func log(category: Category, message: String, isDebug: Bool = false) {
        let line = "[\(category.rawValue)] \(LogRedactor.sweep(message))"
        if isDebug {
            logger.debug("\(line, privacy: .public)")
        } else {
            logger.log("\(line, privacy: .public)")
        }
    }
}
