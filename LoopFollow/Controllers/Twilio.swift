//
//  Twilio.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2024-04-05.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

// Twilio.swift

import Foundation

protocol TwilioRequestable {
    func twilioRequest(combinedString: String, completion: @escaping (Result<Void, Error>) -> Void)
}

extension TwilioRequestable {
    func twilioRequest(combinedString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let twilioSID = UserDefaultsRepository.twilioSIDString.value
        let twilioSecret = UserDefaultsRepository.twilioSecretString.value
        let fromNumber = UserDefaultsRepository.twilioFromNumberString.value
        let toNumber = UserDefaultsRepository.twilioToNumberString.value
        let message = combinedString
        
        // Build the request
        let urlString = "https://\(twilioSID):\(twilioSecret)@api.twilio.com/2010-04-01/Accounts/\(twilioSID)/Messages"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(.failure(NetworkError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "From=\(fromNumber)&To=\(toNumber)&Body=\(message)".data(using: .utf8)
        
        // Build the completion block and send the request
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let httpResponse = response as? HTTPURLResponse {
                    if (200..<300).contains(httpResponse.statusCode) {
                        completion(.success(()))
                    } else {
                        let message = "HTTP Statuskod: \(httpResponse.statusCode)"
                        let error = NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                        completion(.failure(error))
                    }
                } else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Oväntat svar från servern"])
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

enum NetworkError: Error {
    case invalidURL
}
