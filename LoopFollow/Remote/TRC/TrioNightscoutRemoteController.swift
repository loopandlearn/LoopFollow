//
//  TrioNightscoutRemoteController.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-08-26.
//  Copyright © 2024 Jon Fawcett. All rights reserved.
//

import Foundation
import HealthKit

class TrioNightscoutRemoteController {

    func cancelExistingTarget(completion: @escaping (Bool) -> Void) {
        Task {
            let tempTargetBody: [String: Any] = [
                "enteredBy": "LoopFollow",
                "eventType": "Temporary Target",
                "reason": "Manual",
                "duration": 0,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]

            do {
                let response: [TreatmentCancelResponse] = try await NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody)
                Observable.shared.tempTarget.value = nil
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    func sendTempTarget(newTarget: HKQuantity, duration: HKQuantity, completion: @escaping (Bool) -> Void) {
        let tempTargetBody: [String: Any] = [
            "enteredBy": "LoopFollow",
            "eventType": "Temporary Target",
            "reason": "Manual",
            "targetTop": newTarget.doubleValue(for: .milligramsPerDeciliter),
            "targetBottom": newTarget.doubleValue(for: .milligramsPerDeciliter),
            "duration": Int(duration.doubleValue(for: .minute())),
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]

        Task {
            do {
                let response: [TreatmentResponse] = try await NightscoutUtils.executePostRequest(eventType: .treatments, body: tempTargetBody)
                Observable.shared.tempTarget.value = newTarget
                NotificationCenter.default.post(name: NSNotification.Name("refresh"), object: nil)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
}
