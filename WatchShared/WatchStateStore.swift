// LoopFollow
// WatchStateStore.swift

import Foundation

/// Keeps the last state received from the phone in the App Group container, so
/// the watch app shows data at launch and the complications can read it.
enum WatchStateStore {
    private static let fileName = "watch-state.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupID.current())?
            .appendingPathComponent(fileName)
    }

    static func save(_ data: Data) {
        guard let url = fileURL else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> WatchState? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return WatchState.decode(data)
    }
}
