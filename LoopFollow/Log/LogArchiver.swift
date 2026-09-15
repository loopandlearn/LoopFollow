// LoopFollow
// LogArchiver.swift

import Foundation

enum LogArchiver {
    /// Copies `files` into a folder named `archiveName` and returns a zip archive
    /// of that folder in the temporary directory.
    static func zip(files: [URL], archiveName: String) throws -> URL {
        let fileManager = FileManager.default
        let staging = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = staging.appendingPathComponent(archiveName, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        for file in files {
            try fileManager.copyItem(at: file, to: folder.appendingPathComponent(file.lastPathComponent))
        }

        let destination = fileManager.temporaryDirectory.appendingPathComponent("\(archiveName).zip")
        try? fileManager.removeItem(at: destination)

        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipURL in
            do {
                try fileManager.copyItem(at: zipURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        return destination
    }
}
