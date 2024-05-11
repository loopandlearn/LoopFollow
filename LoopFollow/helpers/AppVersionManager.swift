//
//  AppVersionManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-05-11.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation

class AppVersionManager {
    private let githubService = GitHubService()
    
    func checkForNewVersion(completion: @escaping (String?, Bool, Bool) -> Void) {
        let currentVersion = version()
        let now = Date()
        
        // Retrieve cache
        let lastChecked = UserDefaults.standard.object(forKey: "latestVersionChecked") as? Date ?? Date.distantPast
        let cachedLatestVersion = UserDefaults.standard.string(forKey: "latestVersion")
        let isBlacklistedCached = UserDefaults.standard.bool(forKey: "isCurrentVersionBlacklisted")

        // Check if the cache is still valid
        if now.timeIntervalSince(lastChecked) < 24 * 3600, let latestVersion = cachedLatestVersion {
            let isNewer = isVersion(latestVersion, newerThan: currentVersion)
            completion(latestVersion, isNewer, isBlacklistedCached)
            return
        }
        
        // Fetch new data if cache is outdated
        githubService.fetchData(for: .versionConfig) { versionData in
            self.githubService.fetchData(for: .blacklistedVersions) { blacklistData in
                DispatchQueue.main.async {
                    let fetchedVersion = versionData.flatMap { String(data: $0, encoding: .utf8) }
                        .flatMap { self.parseVersionFromConfig(contents: $0) }
                    let isNewer = fetchedVersion.map { self.isVersion($0, newerThan: currentVersion) } ?? false
                    
                    let isBlacklisted = (try? blacklistData.flatMap { try JSONDecoder().decode(Blacklist.self, from: $0) })
                        .map { $0.blacklistedVersions.map { $0.version }.contains(currentVersion) } ?? false
                    
                    // Update cache with new data
                    UserDefaults.standard.set(fetchedVersion, forKey: "latestVersion")
                    UserDefaults.standard.set(Date(), forKey: "latestVersionChecked")
                    UserDefaults.standard.set(isBlacklisted, forKey: "isCurrentVersionBlacklisted")
                    
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
        for i in 0..<maxCount {
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
