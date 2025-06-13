// LoopFollow
// GitHubService.swift
// Created by Jonas Björkert on 2024-05-11.

import Foundation

class GitHubService {
    enum GitHubDataType {
        case versionConfig
        case blacklistedVersions

        var url: String {
            switch self {
            case .versionConfig:
                return "https://raw.githubusercontent.com/loopandlearn/LoopFollow/main/Config.xcconfig"
            case .blacklistedVersions:
                return "https://raw.githubusercontent.com/loopandlearn/LoopFollow/main/blacklisted-versions.json"
            }
        }
    }

    func fetchData(for dataType: GitHubDataType, completion: @escaping (Data?) -> Void) {
        let urlString = dataType.url
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(data)
            } else {
                completion(nil)
            }
        }.resume()
    }
}
