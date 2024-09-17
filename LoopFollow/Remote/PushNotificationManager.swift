//
//  PushNotificationManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-27.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import SwiftJWT
import HealthKit

struct APNsJWTClaims: Claims {
    let iss: String
    let iat: Date
}

class PushNotificationManager {
    private var deviceToken: String
    private var sharedSecret: String
    private var productionEnvironment: Bool
    private var token: String
    private var teamId: String
    private var keyId: String
    private var user: String
    private var bundleId: String

    init() {
        self.deviceToken = Storage.shared.deviceToken.value
        self.sharedSecret = Storage.shared.sharedSecret.value
        self.productionEnvironment = Storage.shared.productionEnvironment.value
        self.token = Storage.shared.token.value
        self.teamId = Storage.shared.teamId.value
        self.keyId = Storage.shared.keyId.value
        self.user = Storage.shared.user.value
        self.bundleId = Storage.shared.bundleId.value
    }

    func sendBolusPushNotification(commandType: String, bolusAmount: HKQuantity, completion: @escaping (Bool) -> Void) {
        let bolusAmount = Decimal(bolusAmount.doubleValue(for: .internationalUnit()))

        let message = PushMessage(
            user: user,
            commandType: commandType,
            bolusAmount: bolusAmount,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendTempTargetPushNotification(target: HKQuantity, duration: HKQuantity, completion: @escaping (Bool) -> Void) {
        let targetValue = Int(target.doubleValue(for: HKUnit.milligramsPerDeciliter))
        let durationValue = Int(duration.doubleValue(for: HKUnit.minute()))

        let message = PushMessage(
            user: user,
            commandType: "temp_target",
            bolusAmount: nil,
            target: targetValue,
            duration: durationValue,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendCancelTempTargetPushNotification(completion: @escaping (Bool) -> Void) {
        let message = PushMessage(
            user: user,
            commandType: "cancel_temp_target",
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
    }

    func sendMealPushNotification(carbs: HKQuantity, protein: HKQuantity, fat: HKQuantity, completion: @escaping (Bool) -> Void) {
        let carbsValue = Int(carbs.doubleValue(for: .gram()))
        let proteinValue = Int(protein.doubleValue(for: .gram()))
        let fatValue = Int(fat.doubleValue(for: .gram()))

        let message = PushMessage(
            user: user,
            commandType: "meal",
            carbs: carbsValue,
            protein: proteinValue,
            fat: fatValue,
            sharedSecret: sharedSecret,
            timestamp: Date().timeIntervalSince1970
        )

        sendPushNotification(message: message, completion: completion)
    }

    private func sendPushNotification(message: PushMessage, completion: @escaping (Bool) -> Void) {
        print("Push message to send: \(message)")
        guard let url = constructAPNsURL() else {
            print("Failed to construct APNs URL")
            completion(false)
            return
        }

        guard let jwt = generateJWT() else {
            print("Failed to generate JWT")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("10", forHTTPHeaderField: "apns-priority")
        request.setValue("0", forHTTPHeaderField: "apns-expiration")
        request.setValue(bundleId, forHTTPHeaderField: "apns-topic")
        request.setValue("background", forHTTPHeaderField: "apns-push-type")

        do {
            let jsonData = try JSONEncoder().encode(message)
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to send push notification: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Push notification sent. Status code: \(httpResponse)")
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
            task.resume()

        } catch {
            print("Failed to encode push message: \(error.localizedDescription)")
            completion(false)
        }
    }

    private func constructAPNsURL() -> URL? {
        let host = productionEnvironment ? "api.push.apple.com" : "api.sandbox.push.apple.com"
        let urlString = "https://\(host)/3/device/\(deviceToken)"
        return URL(string: urlString)
    }

    private func generateJWT() -> String? {
        let header = Header(kid: keyId)
        let claims = APNsJWTClaims(iss: teamId, iat: Date())

        var jwt = JWT(header: header, claims: claims)

        do {
            let privateKey = Data(token.utf8)
            let jwtSigner = JWTSigner.es256(privateKey: privateKey)
            let signedJWT = try jwt.sign(using: jwtSigner)
            return signedJWT
        } catch {
            print("Failed to sign JWT: \(error.localizedDescription)")
            return nil
        }
    }
}
