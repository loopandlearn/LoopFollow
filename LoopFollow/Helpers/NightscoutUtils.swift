//
//  NightscoutUtils.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-04-09.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation

class NightscoutUtils {
    enum NightscoutError: Error, LocalizedError {
        case emptyAddress
        case invalidURL
        case networkError
        case siteNotFound
        case invalidToken
        case tokenRequired
        case unknown

        var errorDescription: String? {
            switch self {
            case .emptyAddress:
                return "The address is empty."
            case .invalidURL:
                return "The URL is invalid."
            case .networkError:
                return "A network error occurred."
            case .siteNotFound:
                return "The site was not found."
            case .invalidToken:
                return "The token is invalid."
            case .tokenRequired:
                return "A token is required."
            case .unknown:
                return "An unknown error occurred."
            }
        }
    }

    enum EventType: String {
        case cage = "Site Change"
        case carbsToday = "Carb Correction"
        case sage = "Sensor Start"
        case sgv
        case profile
        case treatments
        case deviceStatus
        case iage = "Insulin Cartridge Change"

        var endpoint: String {
            switch self {
            case .cage, .carbsToday, .sage, .treatments, .iage:
                return "/api/v1/treatments.json"
            case .sgv:
                return "/api/v1/entries.json"
            case .profile:
                return "/api/v1/profile/current.json"
            case .deviceStatus:
                return "/api/v1/devicestatus.json"
            }
        }
    }

    static func executeRequest<T: Decodable>(eventType: EventType, parameters: [String: String], completion: @escaping (Result<T, Error>) -> Void) {
        let baseURL = ObservableUserDefaults.shared.url.value
        let token = UserDefaultsRepository.token.value

        guard let url = NightscoutUtils.constructURL(baseURL: baseURL, token: token, endpoint: eventType.endpoint, parameters: parameters) else {
            completion(.failure(NSError(domain: "NightscoutUtils", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(error!))
                return
            }

            let decoder = JSONDecoder()
            do {
                let decodedObject = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(decodedObject))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }


    static func executeDynamicRequest(eventType: EventType, parameters: [String: String], completion: @escaping (Result<Any, Error>) -> Void) {
        let baseURL = ObservableUserDefaults.shared.url.value
        let token = UserDefaultsRepository.token.value

        guard let url = NightscoutUtils.constructURL(baseURL: baseURL, token: token, endpoint: eventType.endpoint, parameters: parameters) else {
            completion(.failure(NSError(domain: "NightscoutUtils", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(error!))
                return
            }

            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    DispatchQueue.main.async {
                        completion(.success(jsonObject))
                    }
                } else if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] {
                    DispatchQueue.main.async {
                        completion(.success(jsonArray))
                    }
                } else {
                    completion(.failure(NSError(domain: "NightscoutUtils", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON Structure"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    static func createURLRequest(url: String, token: String?, path: String) -> URLRequest? {
        var requestURLString = "\(url)\(path)"

        if let token = token {
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
            requestURLString += "?token=\(encodedToken)"
        }

        guard let requestURL = URL(string: requestURLString) else {
            return nil
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        return request
    }

    static func constructURL(baseURL: String, token: String?, endpoint: String, parameters: [String: String]) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.path = endpoint

        var queryItems = [URLQueryItem]()

        if let token = token, !token.isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }

        for (key, value) in parameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }

        components?.queryItems = queryItems

        return components?.url
    }

    static func verifyURLAndToken(completion: @escaping (NightscoutError?, String?, Bool) -> Void) {
        let urlUser = ObservableUserDefaults.shared.url.value
        let token = UserDefaultsRepository.token.value

        if urlUser.isEmpty {
            completion(.emptyAddress, nil, false)
            return
        }

        guard let _ = URL(string: urlUser), urlUser.hasPrefix("http://") || urlUser.hasPrefix("https://") else {
            completion(.invalidURL, nil, false)
            return
        }

        guard let request = createURLRequest(url: urlUser, token: token, path: "/api/v1/status.json") else {
            completion(.invalidURL, nil, false)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            var nsWriteAuth = false

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let authorized = jsonResponse["authorized"] as? [String: Any],
                               let token = authorized["token"] as? String,
                               let permissionGroups = authorized["permissionGroups"] as? [[String]] {

                                if permissionGroups.contains(where: { $0.contains("*") }) {
                                    nsWriteAuth = true
                                } else if permissionGroups.contains(where: { $0.contains("api:treatments:create") }) {
                                    nsWriteAuth = true
                                }
                                completion(nil, token, nsWriteAuth)
                            } else {
                                completion(nil, nil, false)
                            }
                        } catch {
                            completion(nil, nil, false)
                        }
                    } else {
                        completion(nil, nil, false)
                    }
                case 401:
                    if token.isEmpty {
                        completion(.tokenRequired, nil, false)
                    } else {
                        completion(.invalidToken, nil, false)
                    }
                default:
                    completion(.unknown, nil, false)
                }
            } else {
                if let _ = error {
                    completion(.siteNotFound, nil, false)
                } else {
                    completion(.networkError, nil, false)
                }
            }
        }
        task.resume()
    }

    static func parseDate(_ dateString: String) -> Date? {
        let dateFormatterWithMilliseconds = DateFormatter()
        dateFormatterWithMilliseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatterWithMilliseconds.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatterWithMilliseconds.locale = Locale(identifier: "en_US_POSIX")

        let dateFormatterWithoutMilliseconds = DateFormatter()
        dateFormatterWithoutMilliseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatterWithoutMilliseconds.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatterWithoutMilliseconds.locale = Locale(identifier: "en_US_POSIX")

        if let date = dateFormatterWithMilliseconds.date(from: dateString) {
            return date
        } else if let date = dateFormatterWithoutMilliseconds.date(from: dateString) {
            return date
        }

        return nil
    }

    static func retrieveJWTToken() async throws -> String {
        let urlUser = ObservableUserDefaults.shared.url.value
        let token = UserDefaultsRepository.token.value

        if urlUser.isEmpty {
            throw NightscoutError.emptyAddress
        }

        guard let request = createURLRequest(url: urlUser, token: token, path: "/api/v1/status.json"),
              urlUser.hasPrefix("http://") || urlUser.hasPrefix("https://") else {
            throw NightscoutError.invalidURL
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.waitsForConnectivity = true
        sessionConfig.networkServiceType = .responsiveData
        let session = URLSession(configuration: sessionConfig)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NightscoutError.networkError
        }

        switch httpResponse.statusCode {
        case 200:
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let authorized = jsonResponse["authorized"] as? [String: Any],
               let jwtToken = authorized["token"] as? String {
                return jwtToken
            } else {
                throw NightscoutError.invalidToken
            }
        case 401:
            throw token.isEmpty ? NightscoutError.tokenRequired : NightscoutError.invalidToken
        default:
            throw NightscoutError.unknown
        }
    }

    static func executePostRequest<T: Decodable>(eventType: EventType, body: [String: Any]) async throws -> T {
        let jwtToken = try await retrieveJWTToken()
        let baseURL = ObservableUserDefaults.shared.url.value

        guard let url = URL(string: "\(baseURL)\(eventType.endpoint)") else {
            throw NightscoutError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.waitsForConnectivity = true
        sessionConfig.networkServiceType = .responsiveData
        let session = URLSession(configuration: sessionConfig)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NightscoutError.networkError
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
