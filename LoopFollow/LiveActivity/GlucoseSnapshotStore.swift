// LoopFollow
// GlucoseSnapshotStore.swift

import Foundation
import os.log

private let storeLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.loopfollow", category: "GlucoseSnapshotStore")

/// Persists the latest GlucoseSnapshot into the App Group container so that:
/// - the Live Activity extension can read it
/// - future Watch + CarPlay surfaces can reuse it
///
/// Uses an atomic JSON file write to avoid partial/corrupt reads across processes.
final class GlucoseSnapshotStore {
    static let shared = GlucoseSnapshotStore()
    private init() {}

    private let fileName = "glucose_snapshot.json"
    private let queue = DispatchQueue(label: "com.loopfollow.glucoseSnapshotStore", qos: .utility)

    // MARK: - Public API

    func save(_ snapshot: GlucoseSnapshot, completion: (() -> Void)? = nil) {
        queue.async {
            do {
                let url = try self.fileURL()
                // GlucoseSnapshot writes `updatedAt` as a Double via its custom
                // encoder, so no JSONEncoder date strategy is required.
                let encoder = JSONEncoder()
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: [.atomic])
                os_log("GlucoseSnapshotStore: saved snapshot g=%d to %{public}@", log: storeLog, type: .debug, Int(snapshot.glucose), url.lastPathComponent)
            } catch {
                os_log("GlucoseSnapshotStore: save failed — %{public}@", log: storeLog, type: .error, error.localizedDescription)
            }
            completion?()
        }
    }

    func load() -> GlucoseSnapshot? {
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                os_log("GlucoseSnapshotStore: file not found at %{public}@", log: storeLog, type: .debug, url.lastPathComponent)
                return nil
            }

            let data = try Data(contentsOf: url)
            // GlucoseSnapshot reads `updatedAt` as a Double via its custom decoder,
            // so no JSONDecoder date strategy is required.
            let decoder = JSONDecoder()
            let snapshot = try decoder.decode(GlucoseSnapshot.self, from: data)
            return snapshot
        } catch {
            os_log("GlucoseSnapshotStore: load failed — %{public}@", log: storeLog, type: .error, error.localizedDescription)
            return nil
        }
    }

    func delete() {
        queue.async {
            do {
                let url = try self.fileURL()
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                // Intentionally silent (extension-safe, no dependencies).
            }
        }
    }

    // MARK: - Helpers

    private func fileURL() throws -> URL {
        let groupID = AppGroupID.current()
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw NSError(
                domain: "GlucoseSnapshotStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App Group containerURL is nil for id=\(groupID)"],
            )
        }
        return containerURL.appendingPathComponent(fileName, isDirectory: false)
    }
}
