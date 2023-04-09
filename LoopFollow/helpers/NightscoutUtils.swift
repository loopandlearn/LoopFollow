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
}
