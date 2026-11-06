// LoopFollow
// HubVersionManager.swift

import Foundation

/// The newest LF Hub version on the branch the connected hub's image is built from: `main`
/// for the `latest` image, `dev` for the `dev` image and for a hub its owner built.
enum HubVersionManager {
    static func branch(for channel: String?) -> String {
        channel == "latest" ? "main" : "dev"
    }

    /// The newest version for the hub's channel, checked at most once a day; the last one
    /// known for that branch when GitHub does not answer, and nil before the first answer.
    @MainActor
    static func latestVersion(for hub: HubClient.Status.Hub) async -> String? {
        let storage = Storage.shared
        let branch = branch(for: hub.channel)
        let cached = storage.hubLatestVersionBranch.value == branch ? storage.hubLatestVersion.value : nil
        let checked = storage.hubLatestVersionChecked.value ?? .distantPast
        if let cached, Date().timeIntervalSince(checked) < 24 * 3600 { return cached }

        guard let url = URL(string: "https://raw.githubusercontent.com/loopandlearn/lfhub/\(branch)/lfhub.csproj"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let version = parseVersion(fromProject: String(decoding: data, as: UTF8.self))
        else { return cached }

        storage.hubLatestVersion.value = version
        storage.hubLatestVersionBranch.value = branch
        storage.hubLatestVersionChecked.value = Date()
        return version
    }

    /// The `<Version>` of an `lfhub.csproj`.
    static func parseVersion(fromProject contents: String) -> String? {
        guard let start = contents.range(of: "<Version>"),
              let end = contents.range(of: "</Version>", range: start.upperBound ..< contents.endIndex)
        else { return nil }
        let version = contents[start.upperBound ..< end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    static func isOutdated(_ hub: HubClient.Status.Hub, latest: String) -> Bool {
        AppVersionManager.isVersion(latest, newerThan: hub.version)
    }
}
