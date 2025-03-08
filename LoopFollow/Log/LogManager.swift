//
//  LogManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-10.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

class LogManager {
    static let shared = LogManager()

    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let dateFormatter: DateFormatter
    private let consoleQueue = DispatchQueue(label: "com.loopfollow.log.console", qos: .background)
    
    private let rateLimitQueue = DispatchQueue(label: "com.loopfollow.log.ratelimit")
    private var lastLoggedTimestamps: [String: Date] = [:]

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
    
    /// Logs a message with an optional rate limit.
    ///
    /// - Parameters:
    ///   - category: The log category.
    ///   - message: The message to log.
    ///   - isDebug: Indicates if this is a debug log.
    ///   - limitIdentifier: Optional key to rate-limit similar log messages.
    ///   - limitInterval: Time interval (in seconds) to wait before logging the same type again.
    func log(category: Category, message: String, isDebug: Bool = false, limitIdentifier: String? = nil, limitInterval: TimeInterval = 300) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] [\(category.rawValue)] \(message)"

        consoleQueue.async {
            print(logMessage)
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
            let logFileURL = self.currentLogFileURL
            self.append(logMessage + "\n", to: logFileURL)
        }
    }

    func cleanupOldLogs() {
        let today = dateFormatter.string(from: Date())
        let yesterday = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            for logFile in logFiles {
                let filename = logFile.lastPathComponent
                if !filename.contains(today) && !filename.contains(yesterday) {
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
