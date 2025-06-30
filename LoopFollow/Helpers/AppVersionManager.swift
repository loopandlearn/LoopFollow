// LoopFollow
// AppVersionManager.swift
// Created by Jonas Björkert.

import Foundation

class AppVersionManager {
    private let githubService = GitHubService()

    func checkForNewVersionAsync() async -> (latest: String?, isNewer: Bool, isBlacklisted: Bool) {
        await withCheckedContinuation { cont in
            checkForNewVersion { latest, newer, blacklisted in
                cont.resume(returning: (latest, newer, blacklisted))
            }
        }
    }

    /// Checks for the availability of a new app version and if the current version is blacklisted.
    /// - Parameter completion: Returns latest version, a boolean for newer version existence, and blacklist status.
    /// Usage: `versionManager.checkForNewVersion { latestVersion, isNewer, isBlacklisted in ... }`
    func checkForNewVersion(completion: @escaping (String?, Bool, Bool) -> Void) {
        let currentVersion = version()
        let now = Date()

        // Retrieve cache
        let latestVersionChecked = Storage.shared.latestVersionChecked.value ?? Date.distantPast
        let latestVersion = Storage.shared.latestVersion.value
        let currentVersionBlackListed = Storage.shared.currentVersionBlackListed.value
        let cachedForVersion = Storage.shared.cachedForVersion.value

        // Reset notifications if version has changed
        if let cachedVersion = cachedForVersion, cachedVersion != currentVersion {
            Storage.shared.lastBlacklistNotificationShown.value = Date.distantPast
            Storage.shared.lastVersionUpdateNotificationShown.value = Date.distantPast
        }

        // Check if the cache is still valid
        if let cachedVersion = cachedForVersion, cachedVersion == currentVersion,
           now.timeIntervalSince(latestVersionChecked) < 24 * 3600, let latestVersion = latestVersion
        {
            let isNewer = isVersion(latestVersion, newerThan: currentVersion)
            completion(latestVersion, isNewer, currentVersionBlackListed)
            return
        }

        // Fetch new data if cache is outdated or not for current version
        fetchDataAndUpdateCache(currentVersion: currentVersion, completion: completion)
    }

    private func fetchDataAndUpdateCache(currentVersion: String, completion: @escaping (String?, Bool, Bool) -> Void) {
        githubService.fetchData(for: .versionConfig) { versionData in
            self.githubService.fetchData(for: .blacklistedVersions) { blacklistData in
                DispatchQueue.main.async {
                    let fetchedVersion = versionData.flatMap { String(data: $0, encoding: .utf8) }
                        .flatMap { self.parseVersionFromConfig(contents: $0) }
                    let isNewer = fetchedVersion.map { self.isVersion($0, newerThan: currentVersion) } ?? false

                    let isBlacklisted = (try? blacklistData.flatMap { try JSONDecoder().decode(Blacklist.self, from: $0) })
                        .map { $0.blacklistedVersions.map { $0.version }.contains(currentVersion) } ?? false

                    // Update cache with new data
                    Storage.shared.latestVersion.value = fetchedVersion
                    Storage.shared.latestVersionChecked.value = Date()
                    Storage.shared.currentVersionBlackListed.value = isBlacklisted
                    Storage.shared.cachedForVersion.value = currentVersion

                    // Call completion with new data
                    completion(fetchedVersion, isNewer, isBlacklisted)
                }
            }
        }
    }

    private func parseVersionFromConfig(contents: String) -> String? {
        let lines = contents.split(separator: "\n")
        for line in lines {
            if line.contains("LOOP_FOLLOW_MARKETING_VERSION") {
                let components = line.split(separator: "=").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if components.count > 1 {
                    return components[1]
                }
            }
        }
        return nil
    }

    private func isVersion(_ fetchedVersion: String, newerThan currentVersion: String) -> Bool {
        let fetchedVersionComponents = fetchedVersion.split(separator: ".").map { Int($0) ?? 0 }
        let currentVersionComponents = currentVersion.split(separator: ".").map { Int($0) ?? 0 }

        let maxCount = max(fetchedVersionComponents.count, currentVersionComponents.count)
        for i in 0 ..< maxCount {
            let fetched = i < fetchedVersionComponents.count ? fetchedVersionComponents[i] : 0
            let current = i < currentVersionComponents.count ? currentVersionComponents[i] : 0
            if fetched > current {
                return true
            } else if fetched < current {
                return false
            }
        }
        return false
    }

    func version() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }

    struct Blacklist: Decodable {
        let blacklistedVersions: [VersionEntry]
    }

    struct VersionEntry: Decodable {
        let version: String
    }
}
