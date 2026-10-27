// LoopFollow
// APNSDelivery.swift

import Foundation

/// Sends one remote command push to the Loop or Trio app. Used by the phone and
/// by the watch when it sends without the phone.
enum APNSDelivery {
    /// Calls `completion` on an arbitrary queue with success, or the reason for failure.
    static func send(
        body: Data,
        deviceToken: String,
        topic: String,
        production: Bool,
        keyId: String,
        teamId: String,
        apnsKey: String,
        expiration: String? = nil,
        collapseID: String? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let jwt = JWTManager.shared.getOrGenerateJWT(keyId: keyId, teamId: teamId, apnsKey: apnsKey) else {
            let errorMessage = "Failed to generate JWT, please check that the APNS Key ID, APNS Key and Team ID are correct."
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        guard let url = URL(string: "\(APNSEnvironment.baseURL(production: production))/3/device/\(deviceToken)") else {
            let errorMessage = "Failed to construct APNs URL"
            LogManager.shared.log(category: .apns, message: errorMessage)
            completion(false, errorMessage)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue(topic, forHTTPHeaderField: "apns-topic")
        request.setValue("alert", forHTTPHeaderField: "apns-push-type")
        if let expiration {
            request.setValue(expiration, forHTTPHeaderField: "apns-expiration")
        }
        if let collapseID {
            request.setValue(collapseID, forHTTPHeaderField: "apns-collapse-id")
        }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                let errorMessage = "Failed to send push notification: \(error.localizedDescription)"
                LogManager.shared.log(category: .apns, message: errorMessage)
                completion(false, errorMessage)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                let errorMessage = "Failed to get a valid HTTP response."
                LogManager.shared.log(category: .apns, message: errorMessage)
                completion(false, errorMessage)
                return
            }

            var reason = ""
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let value = json["reason"] as? String
            {
                reason = value
            }

            if httpResponse.statusCode == 200 {
                LogManager.shared.log(category: .apns, message: "APNS notification sent successfully")
                completion(true, nil)
                return
            }
            if httpResponse.statusCode == 403 {
                JWTManager.shared.invalidateCache()
            }
            LogManager.shared.log(category: .apns, message: "APNS error \(httpResponse.statusCode): \(reason)")
            completion(false, "\(message(forStatus: httpResponse.statusCode)) \(reason)")
        }.resume()
    }

    static func message(forStatus status: Int) -> String {
        switch status {
        case 400: "Bad request. The request was invalid or malformed."
        case 403: "Authentication error. Check your certificate or authentication token."
        case 404: "Invalid request: The :path value was incorrect."
        case 405: "Invalid request: Only POST requests are supported."
        case 410: "The device token is no longer active for the topic."
        case 413: "Payload too large. The notification payload exceeded the size limit."
        case 429: "Too many requests."
        case 500: "Internal server error at APNs."
        case 503: "Service unavailable. The server is temporarily unavailable. Try again later."
        default: "Unexpected status code: \(status)."
        }
    }
}
