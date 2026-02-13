// LoopFollow
// AuthService.swift

import Foundation
import LocalAuthentication

public enum AuthResult {
    case success
    case canceled
    case unavailable(String)
    case failed
}

public enum AuthService {
    /// Unified authentication that prefers biometrics and falls back to passcode automatically.
    /// - Parameters:
    ///   - reason: Shown in the system auth prompt.
    ///   - reuseDuration: Optional Touch ID/Face ID reuse window (seconds). 0 disables reuse.
    ///   - completion: Returns an `AuthResult` representing the outcome.
    public static func authenticate(reason: String,
                                    reuseDuration: TimeInterval = 0,
                                    completion: @escaping (AuthResult) -> Void)
    {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        if reuseDuration > 0 {
            context.touchIDAuthenticationAllowableReuseDuration = reuseDuration
        }

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            var message = "Device authentication is not available. "

            let biometryType = context.biometryType
            if biometryType == .none {
                message += "Please enable Face ID, Touch ID, or set up a device passcode in Settings."
            } else if biometryType == .faceID {
                message += "Face ID is not available. Please set up a device passcode in Settings."
            } else if biometryType == .touchID {
                message += "Touch ID is not available. Please set up a device passcode in Settings."
            }

            DispatchQueue.main.async {
                completion(.unavailable(message))
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, err in
            DispatchQueue.main.async {
                if success {
                    completion(.success)
                    return
                }
                if let e = err as? LAError {
                    switch e.code {
                    case .userCancel, .systemCancel, .appCancel:
                        completion(.canceled)
                    default:
                        completion(.failed)
                    }
                } else {
                    completion(.failed)
                }
            }
        }
    }
}
