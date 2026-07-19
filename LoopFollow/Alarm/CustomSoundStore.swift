// LoopFollow
// CustomSoundStore.swift

import AVFoundation
import Foundation

/// A user-imported alarm sound stored inside the app's Documents directory.
struct CustomSound: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let url: URL
}

/// Manages the pool of user-imported alarm sounds.
///
/// Files live in `Documents/CustomSounds/<uuid>.<ext>`. A tiny sidecar `index.json`
/// maps each UUID to its original filename so the picker can show something meaningful.
/// Files dropped into `Documents/` via the Files app are picked up on next `list()` and
/// moved into `CustomSounds/` with a fresh UUID.
final class CustomSoundStore {
    static let shared = CustomSoundStore()

    /// Hard cap on imported audio file size. Alarm sounds should be short; this prevents
    /// users from accidentally importing a full podcast episode.
    static let maxFileBytes: Int = 2 * 1024 * 1024 // 2 MB
    /// Hard cap on audio duration. Alarms loop or repeat via their own delay, so long clips
    /// provide no benefit and bloat storage.
    static let maxDurationSeconds: TimeInterval = 30

    enum ImportError: LocalizedError {
        case unreadable
        case tooLarge(Int)
        case tooLong(TimeInterval)
        case notAudio

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read the selected file."
            case let .tooLarge(bytes):
                let mb = Double(bytes) / (1024 * 1024)
                return String(format: "File is too large (%.1f MB). Max %d MB.",
                              mb, CustomSoundStore.maxFileBytes / (1024 * 1024))
            case let .tooLong(seconds):
                return String(format: "Audio is too long (%.1fs). Max %.0fs.",
                              seconds, CustomSoundStore.maxDurationSeconds)
            case .notAudio: return "That file isn't a supported audio format."
            }
        }
    }

    private let fileManager = FileManager.default
    private let directory: URL
    private let indexURL: URL
    private let queue = DispatchQueue(label: "CustomSoundStore", qos: .userInitiated)
    private var index: [UUID: String] = [:]

    private init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        directory = documents.appendingPathComponent("CustomSounds", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        loadIndex()
    }

    // MARK: - Public API

    /// All custom sounds available, sorted by display name.
    func list() -> [CustomSound] {
        return queue.sync {
            absorbDroppedFiles()
            pruneMissing()
            return index.compactMap { id, name in
                guard let url = fileURL(for: id) else { return nil }
                return CustomSound(id: id, displayName: name, url: url)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    /// Display name for a given custom sound, or nil if it's been deleted.
    func displayName(for id: UUID) -> String? {
        queue.sync { index[id] }
    }

    /// Resolve a custom sound to its on-disk URL, or nil if missing.
    func url(for id: UUID) -> URL? {
        queue.sync { fileURL(for: id) }
    }

    /// Import the audio at `sourceURL` into the store, validate it, and return a reference.
    func importFile(at sourceURL: URL) throws -> CustomSound {
        try queue.sync {
            let needsScope = sourceURL.startAccessingSecurityScopedResource()
            defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }

            // Validate in place before touching the file so a rejected import never
            // deletes the user's original.
            let size = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size > Self.maxFileBytes {
                throw ImportError.tooLarge(size)
            }
            if !validateAudio(at: sourceURL) {
                throw ImportError.notAudio
            }
            if let duration = audioDuration(at: sourceURL), duration > Self.maxDurationSeconds {
                throw ImportError.tooLong(duration)
            }

            let newID = UUID()
            let ext = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension
            let destURL = directory.appendingPathComponent("\(newID.uuidString).\(ext)")

            // If the picked file already lives in our shared Documents folder, move it
            // so absorbDroppedFiles() won't re-ingest the leftover original as a
            // duplicate. Otherwise copy, leaving the source untouched.
            let documentsRoot = directory.deletingLastPathComponent().resolvingSymlinksInPath().path
            let sourceInDocuments = sourceURL.resolvingSymlinksInPath().path.hasPrefix(documentsRoot + "/")
            do {
                if sourceInDocuments {
                    try fileManager.moveItem(at: sourceURL, to: destURL)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                }
            } catch {
                throw ImportError.unreadable
            }

            let displayName = sourceURL.deletingPathExtension().lastPathComponent
            index[newID] = displayName.isEmpty ? "Custom Sound" : displayName
            saveIndex()
            return CustomSound(id: newID, displayName: index[newID]!, url: destURL)
        }
    }

    /// Delete a custom sound. Alarms referencing it will fall back to the default built-in.
    func delete(_ id: UUID) {
        queue.sync {
            if let url = fileURL(for: id) {
                try? fileManager.removeItem(at: url)
            }
            index.removeValue(forKey: id)
            saveIndex()
        }
    }

    // MARK: - Internals

    private func fileURL(for id: UUID) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return nil
        }
        let prefix = id.uuidString + "."
        guard let match = contents.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return directory.appendingPathComponent(match)
    }

    private func loadIndex() {
        guard
            let data = try? Data(contentsOf: indexURL),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            index = [:]
            return
        }
        var result: [UUID: String] = [:]
        for (key, value) in decoded {
            if let uuid = UUID(uuidString: key) {
                result[uuid] = value
            }
        }
        index = result
    }

    private func saveIndex() {
        let encodable = Dictionary(uniqueKeysWithValues: index.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(encodable) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    /// Drop entries from the index that point to files that no longer exist on disk
    /// (e.g. the user deleted them via the Files app).
    private func pruneMissing() {
        var didChange = false
        for id in Array(index.keys) where fileURL(for: id) == nil {
            index.removeValue(forKey: id)
            didChange = true
        }
        if didChange { saveIndex() }
    }

    /// Pick up audio files that were dropped into the Documents directory via the
    /// Files app and move them into `CustomSounds/` with a fresh UUID.
    ///
    /// Each candidate is validated *in place* against the same size/duration/format
    /// rules as `importFile(at:)` before being moved. A file that fails any check is
    /// left untouched in Documents — we never move (and therefore never delete) a file
    /// the user put there.
    private func absorbDroppedFiles() {
        let documents = directory.deletingLastPathComponent()
        guard let entries = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: [.fileSizeKey]) else {
            return
        }
        let audioExtensions: Set<String> = ["mp3", "wav", "m4a", "aac", "aif", "aiff", "caf"]
        var didChange = false
        for entry in entries {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDir), !isDir.boolValue else { continue }
            guard audioExtensions.contains(entry.pathExtension.lowercased()) else { continue }

            let size = (try? entry.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= Self.maxFileBytes, validateAudio(at: entry) else { continue }
            if let duration = audioDuration(at: entry), duration > Self.maxDurationSeconds { continue }

            let newID = UUID()
            let dest = directory.appendingPathComponent("\(newID.uuidString).\(entry.pathExtension)")
            do {
                try fileManager.moveItem(at: entry, to: dest)
            } catch {
                continue
            }
            let baseName = entry.deletingPathExtension().lastPathComponent
            index[newID] = baseName.isEmpty ? "Custom Sound" : baseName
            didChange = true
        }
        if didChange { saveIndex() }
    }

    private func validateAudio(at url: URL) -> Bool {
        return (try? AVAudioPlayer(contentsOf: url)) != nil
    }

    private func audioDuration(at url: URL) -> TimeInterval? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        return player.duration
    }
}
