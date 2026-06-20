// LoopFollow
// NightscoutUtils.swift

import CryptoKit
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
                return "/api/v1/profiles.json"
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
                let typeName = String(describing: T.self)
                switch decodingError {
                case let .typeMismatch(type, context):
                    LogManager.shared.log(category: .nightscout, message: "Decode \(typeName) typeMismatch: \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", isDebug: true)
                case let .valueNotFound(type, context):
                    LogManager.shared.log(category: .nightscout, message: "Decode \(typeName) valueNotFound: \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", isDebug: true)
                case let .keyNotFound(key, context):
                    LogManager.shared.log(category: .nightscout, message: "Decode \(typeName) keyNotFound: '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", isDebug: true)
                case .dataCorrupted:
                    LogManager.shared.log(category: .nightscout, message: "Decode \(typeName) dataCorrupted", isDebug: true)
                @unknown default:
                    LogManager.shared.log(category: .nightscout, message: "Decode \(typeName) unknown error", isDebug: true)
                }
                completion(.failure(decodingError))
            } catch {
                LogManager.shared.log(category: .nightscout, message: "Decode \(T.self) general error: \(String(describing: type(of: error)))", isDebug: true)
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

    // MARK: - Token Provisioning

    /// Name of the Nightscout authorization subject LoopFollow creates when a
    /// user provisions a token from their API secret.
    static let provisionedSubjectName = "LoopFollow"

    private struct AuthSubject: Decodable {
        let id: String?
        let name: String?
        let accessToken: String?
        let roles: [String]?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name, accessToken, roles
        }
    }

    /// Creates (or reuses) a read-only Nightscout access token using the site's
    /// API secret. The secret only authorizes these requests and is never
    /// persisted. Returns the access token for a `readable` subject named
    /// `provisionedSubjectName`.
    ///
    /// The full API secret authenticates as Nightscout's `admin` role (the `*`
    /// permission), which includes `admin:api:subjects:create`.
    ///
    /// Nightscout serves the subjects list from an in-memory cache that doesn't
    /// refresh promptly after a write, so a freshly-created subject (and its
    /// token) can't be read back reliably right after creating it. Instead we
    /// derive the token locally: it's a pure function of the subject's `_id`
    /// (returned by the create call) and the API secret. See `accessToken(for:)`.
    static func provisionReadOnlyToken(url: String, secret: String) async throws -> String {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { throw NightscoutError.emptyAddress }
        guard let baseURL = URL(string: trimmedURL),
              trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://")
        else { throw NightscoutError.invalidURL }

        let secretHash = sha1Hex(secret)

        // Reuse an existing subject if one is already visible (idempotent re-runs
        // once the site's cache has caught up).
        if let existing = try await fetchProvisionedToken(baseURL: baseURL, secretHash: secretHash) {
            return existing
        }

        let id = try await createReadOnlySubject(baseURL: baseURL, secretHash: secretHash)
        return accessToken(forName: provisionedSubjectName, id: id, secretHash: secretHash)
    }

    /// Returns `true` when `secret` authenticates as the site's API secret.
    /// Read-only: it probes an admin-gated endpoint with the hashed secret and
    /// creates nothing, so it's safe to call just to find out what the user pasted.
    static func verifyAPISecret(url: String, secret: String) async -> Bool {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty,
              let baseURL = URL(string: trimmedURL),
              trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://")
        else { return false }

        let endpoint = baseURL.appendingPathComponent("api/v2/authorization/subjects")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(sha1Hex(trimmedSecret), forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private static func fetchProvisionedToken(baseURL: URL, secretHash: String) async throws -> String? {
        let url = baseURL.appendingPathComponent("api/v2/authorization/subjects")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(secretHash, forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateProvisioningResponse(response)

        let subjects = try JSONDecoder().decode([AuthSubject].self, from: data)
        return subjects.first(where: { $0.name == provisionedSubjectName })?.accessToken
    }

    /// Creates the subject and returns its `_id`.
    private static func createReadOnlySubject(baseURL: URL, secretHash: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/v2/authorization/subjects")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(secretHash, forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": provisionedSubjectName,
            "roles": ["readable"],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateProvisioningResponse(response)

        // Nightscout returns the created subject wrapped in an array
        // (`[{…}]`) on current versions, but a bare object on some older ones,
        // so accept either shape.
        let subject = try decodeCreatedSubject(from: data)
        guard let id = subject.id, !id.isEmpty else { throw NightscoutError.unknown }
        return id
    }

    private static func decodeCreatedSubject(from data: Data) throws -> AuthSubject {
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([AuthSubject].self, from: data) {
            guard let first = array.first else { throw NightscoutError.unknown }
            return first
        }
        return try decoder.decode(AuthSubject.self, from: data)
    }

    /// Reproduces Nightscout's subject-token derivation (`lib/authorization`):
    ///   abbrev = name lowercased, non-`\w` characters removed, first 10 chars
    ///   digest = sha1( sha1Hex(apiSecret) + subjectId )
    ///   token  = "\(abbrev)-\(digest[0..<16])"
    private static func accessToken(forName name: String, id: String, secretHash: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
        let abbrev = String(name.lowercased().filter { allowed.contains($0) }.prefix(10))
        let digest = sha1Hex(secretHash + id)
        return abbrev + "-" + String(digest.prefix(16))
    }

    private static func validateProvisioningResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NightscoutError.networkError
        }
        switch http.statusCode {
        case 200 ..< 300:
            return
        case 401, 403:
            // The API secret was missing or wrong.
            throw NightscoutError.invalidToken
        case 404:
            throw NightscoutError.siteNotFound
        default:
            throw NightscoutError.unknown
        }
    }

    private static func sha1Hex(_ string: String) -> String {
        Insecure.SHA1.hash(data: Data(string.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
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
