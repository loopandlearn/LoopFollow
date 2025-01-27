//
//  LoopOverrideViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

final class LoopOverrideViewModel: ObservableObject, Sendable {
    func sendActivateOverrideRequest(
        override: ProfileManager.LoopOverride,
        completion: @escaping (Bool, String?) -> Void
    ) {
        Task {
            let body: [String: Any] = [
                "eventType": "Temporary Override",
                "enteredBy": Storage.shared.user.value,
                "reason": override.name,
                "reasonDisplay": "\(override.symbol) \(override.name)"
            ]

            do {
                let response: String = try await NightscoutUtils.executePostRequest(eventType: .temporaryOverride, body: body)
                DispatchQueue.main.async {
                    if response == "OK" {
                        Observable.shared.override.value = nil
                        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
                        completion(true, response)
                    } else {
                        let errorTitle = NightscoutUtils.extractErrorReason(from: response)
                        let formattedError = self.formatErrorMessage(errorTitle)
                        completion(false, formattedError)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }

    func sendCancelOverrideRequest(completion: @escaping (Bool, String?) -> Void) {
        Task {
            let body: [String: Any] = [
                "eventType": "Temporary Override Cancel"
            ]

            do {
                let response: String = try await NightscoutUtils.executePostRequest(eventType: .temporaryOverrideCancel, body: body)
                DispatchQueue.main.async {
                    if response == "OK" {
                        Observable.shared.override.value = nil
                        NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
                        completion(true, response)
                    } else {
                        let errorTitle = NightscoutUtils.extractErrorReason(from: response)
                        let formattedError = self.formatErrorMessage(errorTitle)
                        completion(false, formattedError)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }

    func formatErrorMessage(_ errorTitle: String) -> String {
        switch errorTitle {
        case "Unauthorized":
            return "Unauthorized, verify that your token is correct and has admin auth"
        case "APNs delivery failed: BadDeviceToken":
            return "APNs delivery failed: BadDeviceToken, verify that the production setting or Browser/XCode build setting is correct in your Nightscout setup."
        default:
            return errorTitle
        }
    }
}
