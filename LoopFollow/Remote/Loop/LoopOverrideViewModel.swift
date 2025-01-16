//
//  LoopOverrideViewModel.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-01-15.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation

class LoopOverrideViewModel: ObservableObject {
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
                        let errorTitle = NightscoutUtils.extractTitle(from: response) ?? response
                        completion(false, errorTitle)
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
                        let errorTitle = NightscoutUtils.extractTitle(from: response) ?? response
                        completion(false, errorTitle)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }
}

