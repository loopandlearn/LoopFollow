// LoopFollow
// NightscoutUtils.swift
// Created by bjorkert on 2023-04-09.

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
        case iage = "Insulin Change"
        case temporaryOverride = "Temporary Override"
        case temporaryOverrideCancel = "Temporary Override Cancel"

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
            case .temporaryOverride, .temporaryOverrideCancel:
                return "/api/v2/notifications/loop"
            }
        }
    }

    static func executeRequest<T: Decodable>(eventType: EventType, parameters: [String: String], completion: @escaping (Result<T, Error>) -> Void) {
        let baseURL = Storage.shared.url.value
        let token = Storage.shared.token.value

        guard let url = NightscoutUtils.constructURL(baseURL: baseURL, token: token, endpoint: eventType.endpoint, parameters: parameters) else {
            completion(.failure(NSError(domain: "NightscoutUtils", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
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
            } catch let decodingError as DecodingError {
                print("[ERROR] Failed to decode \(T.self):")
                switch decodingError {
                case let .typeMismatch(type, context):
                    print("Type mismatch for type \(type), context: \(context.debugDescription)")
                    print("Coding path:", context.codingPath)
                case let .valueNotFound(type, context):
                    print("Value not found for type \(type), context: \(context.debugDescription)")
                    print("Coding path:", context.codingPath)
                case let .keyNotFound(key, context):
                    print("Key '\(key.stringValue)' not found, context: \(context.debugDescription)")
                    print("Coding path:", context.codingPath)
                case let .dataCorrupted(context):
                    print("Data corrupted, context: \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
                completion(.failure(decodingError))
            } catch {
                print("[ERROR] General error:", error)
                completion(.failure(error))
            }
        }
        task.resume()
    }

    static func executeDynamicRequest(eventType: EventType, parameters: [String: String], completion: @escaping (Result<Any, Error>) -> Void) {
        let baseURL = Storage.shared.url.value
        let token = Storage.shared.token.value

        guard let url = NightscoutUtils.constructURL(baseURL: baseURL, token: token, endpoint: eventType.endpoint, parameters: parameters) else {
            completion(.failure(NSError(domain: "NightscoutUtils", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
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

    static func verifyURLAndToken(completion: @escaping (NightscoutError?, String?, Bool, Bool) -> Void) {
        let urlUser = Storage.shared.url.value
        let token = Storage.shared.token.value

        if urlUser.isEmpty {
            completion(.emptyAddress, nil, false, false)
            return
        }

        guard let _ = URL(string: urlUser), urlUser.hasPrefix("http://") || urlUser.hasPrefix("https://") else {
            completion(.invalidURL, nil, false, false)
            return
        }

        guard let request = createURLRequest(url: urlUser, token: token, path: "/api/v1/status.json") else {
            completion(.invalidURL, nil, false, false)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            var nsWriteAuth = false
            var nsAdminAuth = false

            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if let data = data {
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                               let authorized = jsonResponse["authorized"] as? [String: Any],
                               let token = authorized["token"] as? String,
                               let permissionGroups = authorized["permissionGroups"] as? [[String]]
                            {
                                if permissionGroups.contains(where: { $0.contains("*") }) {
                                    nsWriteAuth = true
                                    nsAdminAuth = true
                                } else if permissionGroups.contains(where: { $0.contains("api:treatments:create") }) {
                                    nsWriteAuth = true
                                }
                                completion(nil, token, nsWriteAuth, nsAdminAuth)
                            } else {
                                completion(nil, nil, false, false)
                            }
                        } catch {
                            completion(nil, nil, false, false)
                        }
                    } else {
                        completion(nil, nil, false, false)
                    }
                case 401:
                    if token.isEmpty {
                        completion(.tokenRequired, nil, false, false)
                    } else {
                        completion(.invalidToken, nil, false, false)
                    }
                default:
                    completion(.unknown, nil, false, false)
                }
            } else {
                if let _ = error {
                    completion(.siteNotFound, nil, false, false)
                } else {
                    completion(.networkError, nil, false, false)
                }
            }
        }
        task.resume()
    }

    static func parseDate(_ rawString: String) -> Date? {
        var mutableDate = rawString

        if mutableDate.hasSuffix("Z") {
            mutableDate = String(mutableDate.dropLast())
        } else if let offsetRange = mutableDate.range(of: "[\\+\\-]\\d{2}:\\d{2}$",
                                                      options: .regularExpression)
        {
            mutableDate.removeSubrange(offsetRange)
        }

        mutableDate = mutableDate.replacingOccurrences(
            of: "\\.\\d+",
            with: "",
            options: .regularExpression
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        let result = dateFormatter.date(from: mutableDate)
        if result == nil {
            print("Unable to parse string: '\(mutableDate)'")
        }
        return result
    }

    static func retrieveJWTToken() async throws -> String {
        let urlUser = Storage.shared.url.value
        let token = Storage.shared.token.value

        if urlUser.isEmpty {
            throw NightscoutError.emptyAddress
        }

        guard let request = createURLRequest(url: urlUser, token: token, path: "/api/v1/status.json"),
              urlUser.hasPrefix("http://") || urlUser.hasPrefix("https://")
        else {
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
               let jwtToken = authorized["token"] as? String
            {
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
        let baseURL = Storage.shared.url.value

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

    static func executePostRequest(eventType: EventType, body: [String: Any]) async throws -> String {
        let jwtToken = try await retrieveJWTToken()
        let baseURL = Storage.shared.url.value

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

        var responseString: String
        responseString = String(data: data, encoding: .utf8) ?? ""
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if responseString != "" {
                return responseString
            } else {
                throw NightscoutError.networkError
            }
        }

        return responseString
    }

    static func extractErrorReason(from responseString: String) -> String {
        // 1) Try to parse the entire string as JSON and return the "message"
        if let data = responseString.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let message = json["message"] as? String
            {
                return message
            }
        }

        // 2) If not valid JSON (or no "message"), try to parse it as HTML <title>
        if let startRange = responseString.range(of: "<title>"),
           let endRange = responseString.range(of: "</title>")
        {
            let titleRange = startRange.upperBound ..< endRange.lowerBound
            let titleContent = responseString[titleRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !titleContent.isEmpty {
                return titleContent
            }
        }

        // 3) Fallback: just return the entire raw string
        return responseString
    }
}
