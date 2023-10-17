//
//  NightscoutUtils.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2023-04-09.
//  Copyright © 2023 Jon Fawcett. All rights reserved.
//

import Foundation

class NightscoutUtils {
    enum NightscoutError {
        case emptyAddress
        case invalidURL
        case networkError
        case siteNotFound
        case invalidToken
        case tokenRequired
        case unknown
    }
    
    enum EventType: String {
        case cage = "Site Change"
        case carbsToday = "Carb Correction"
        case sage = "Sensor Start"
        case sgv
        case profile
        case treatments
        case deviceStatus
        
        var endpoint: String {
            switch self {
            case .cage, .carbsToday, .sage, .treatments:
                return "/api/v1/treatments.json"
            case .sgv:
                return "/api/v1/entries/sgv.json"
            case .profile:
                return "/api/v1/profile/current.json"
            case .deviceStatus: 
                return "/api/v1/devicestatus.json"
            }
        }
    }
    
    static func executeRequest<T: Decodable>(eventType: EventType, parameters: [String: String], completion: @escaping (Result<T, Error>) -> Void) {
        let baseURL = UserDefaultsRepository.url.value
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
        let baseURL = UserDefaultsRepository.url.value
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
    
    @available(*, deprecated, message: "Use constructURL instead.")
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
    
    static func verifyURLAndToken(urlUser: String, token: String?, completion: @escaping (NightscoutError?) -> Void) {
        if urlUser.isEmpty {
            completion(.emptyAddress)
            return
        }

        guard let request = createURLRequest(url: urlUser, token: token, path: "/api/v1/status") else {
            completion(.invalidURL)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    completion(nil)
                case 401:
                    if token == nil || token!.isEmpty {
                        completion(.tokenRequired)
                    } else {
                        completion(.invalidToken) // Change this from "unauthorized"
                    }
                default:
                    completion(.unknown)
                }
            }  else {
                if let _ = error {
                    completion(.siteNotFound)
                } else {
                    completion(.networkError)
                }
            }
        }
        task.resume()
    }
    
    static func parseDate(_ dateString: String) -> Date? {
        let dateFormatterWithMilliseconds = DateFormatter()
        dateFormatterWithMilliseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatterWithMilliseconds.timeZone = TimeZone(abbreviation: "UTC")
        
        let dateFormatterWithoutMilliseconds = DateFormatter()
        dateFormatterWithoutMilliseconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatterWithoutMilliseconds.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = dateFormatterWithMilliseconds.date(from: dateString) {
            return date
        } else if let date = dateFormatterWithoutMilliseconds.date(from: dateString) {
            return date
        }
        
        return nil
    }
}
