// LoopFollow
// LogManager.swift
// Created by Jonas Björkert on 2025-01-13.

import Foundation

class LogManager {
    static let shared = LogManager()

    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let dateFormatter: DateFormatter
    private let consoleQueue = DispatchQueue(label: "com.loopfollow.log.console", qos: .background)

    private let rateLimitQueue = DispatchQueue(label: "com.loopfollow.log.ratelimit")
    private var lastLoggedTimestamps: [String: Date] = [:]

    private var shouldLogVersionHeader: Bool = true

    enum Category: String, CaseIterable {
        case bluetooth = "Bluetooth"
        case nightscout = "Nightscout"
        case apns = "APNS"
        case general = "General"
        case contact = "Contact"
        case taskScheduler = "Task Scheduler"
        case dexcom = "Dexcom"
        case alarm = "Alarm"
        case calendar = "Calendar"
        case deviceStatus = "Device Status"
    }

    init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        logDirectory = documentsDirectory.appendingPathComponent("Logs")
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    private func formattedLogMessage(for category: Category, message: String) -> String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        return "[\(timestamp)] [\(category.rawValue)] \(message)"
    }

    /// Logs a message with an optional rate limit.
    ///
    /// - Parameters:
    ///   - category: The log category.
    ///   - message: The message to log.
    ///   - isDebug: Indicates if this is a debug log.
    ///   - limitIdentifier: Optional key to rate-limit similar log messages.
    ///   - limitInterval: Time interval (in seconds) to wait before logging the same type again.
    func log(category: Category, message: String, isDebug: Bool = false, limitIdentifier: String? = nil, limitInterval: TimeInterval = 300) {
        let logMessage = formattedLogMessage(for: category, message: message)

        consoleQueue.async {
            print(logMessage)
        }

        if category == .taskScheduler && isDebug {
            return
        }

        if let key = limitIdentifier, !Storage.shared.debugLogLevel.value {
            let shouldLog: Bool = rateLimitQueue.sync {
                if let lastLogged = lastLoggedTimestamps[key] {
                    let interval = Date().timeIntervalSince(lastLogged)
                    if interval < limitInterval {
                        return false
                    }
                }
                lastLoggedTimestamps[key] = Date()
                return true
            }
            if !shouldLog {
                return
            }
        }

        if !isDebug || Storage.shared.debugLogLevel.value {
            let logFileURL = currentLogFileURL
            writeVersionHeaderIfNeeded(for: logFileURL)
            append(logMessage + "\n", to: logFileURL)
        }
    }

    /// Helper method: checks if the log file is empty.
    private func isLogFileEmpty(at fileURL: URL) -> Bool {
        if !fileManager.fileExists(atPath: fileURL.path) { return true }
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? UInt64
        {
            return fileSize == 0
        }
        return false
    }

    /// Helper method: writes the version header if needed.
    private func writeVersionHeaderIfNeeded(for fileURL: URL) {
        if shouldLogVersionHeader || isLogFileEmpty(at: fileURL) {
            let versionManager = AppVersionManager()
            let version = versionManager.version()

            // Retrieve build details
            let buildDetails = BuildDetails.default
            let formattedBuildDate = dateTimeUtils.formattedDate(from: buildDetails.buildDate())
            let branchAndSha = buildDetails.branchAndSha
            let expiration = dateTimeUtils.formattedDate(from: buildDetails.calculateExpirationDate())
            let expirationHeaderString = buildDetails.expirationHeaderString
            let isMacApp = buildDetails.isMacApp()
            let isSimulatorBuild = buildDetails.isSimulatorBuild()

            // Assemble header information
            var headerLines = [String]()
            headerLines.append("LoopFollow Version: \(version)")
            if !isMacApp, !isSimulatorBuild {
                headerLines.append("\(expirationHeaderString): \(expiration)")
            }
            headerLines.append("Built: \(formattedBuildDate)")
            headerLines.append("Branch: \(branchAndSha)")

            let headerMessage = headerLines.joined(separator: ", ") + "\n"
            let logMessage = formattedLogMessage(for: .general, message: headerMessage)

            append(logMessage, to: fileURL)
            shouldLogVersionHeader = false
        }
    }

    func cleanupOldLogs() {
        let today = dateFormatter.string(from: Date())
        let yesterday = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            for logFile in logFiles {
                let filename = logFile.lastPathComponent
                if !filename.contains(today), !filename.contains(yesterday) {
                    try fileManager.removeItem(at: logFile)
                }
            }
        } catch {
            print("Failed to clean up old logs: \(error)")
        }
    }

    func logFileURL(for date: Date) -> URL {
        let dateString = dateFormatter.string(from: date)
        return logDirectory.appendingPathComponent("LoopFollow \(dateString).log")
    }

    func logFilesForTodayAndYesterday() -> [URL] {
        let today = logFileURL(for: Date())
        let yesterday = logFileURL(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        return [today, yesterday].filter { fileManager.fileExists(atPath: $0.path) }
    }

    var currentLogFileURL: URL {
        return logFileURL(for: Date())
    }

    private func append(_ message: String, to fileURL: URL) {
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            if let data = message.data(using: .utf8) {
                fileHandle.write(data)
            }
        } else {
            print("Failed to open log file at \(fileURL.path)")
        }
    }
}
